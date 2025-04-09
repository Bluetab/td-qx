defmodule TdQx.Search.StoreTest do
  use TdQx.DataCase

  alias TdCluster.TestHelpers.TdDdMock
  alias TdCluster.TestHelpers.TdDfMock
  alias TdQx.QualityControls.QualityControlVersion
  alias TdQx.Scores.ScoreGroup
  alias TdQx.Search.Store

  @template %{
    id: 1,
    content: [
      %{
        "fields" => [
          %{
            "cardinality" => "?",
            "default" => %{"origin" => "default", "value" => ""},
            "label" => "control quality",
            "name" => "control quality",
            "type" => "string",
            "values" => nil,
            "widget" => "string"
          }
        ],
        "name" => ""
      }
    ],
    label: "quality control",
    name: "quality control",
    scope: "quality_control",
    subscope: nil
  }

  @template_score %{
    id: 5,
    name: "foo",
    label: "score_group",
    scope: "qxe",
    content: [
      %{
        name: "",
        fields: [
          %{
            name: "Quality Principle",
            type: "string",
            label: "Quality Principle",
            values: %{
              fixed: [
                "Completeness",
                "Accuracy",
                "Consistency",
                "Timeliness",
                "Validity",
                "Uniqueness"
              ]
            },
            widget: "dropdown",
            default: %{value: "", origin: "default"},
            cardinality: "?",
            subscribable: false
          },
          %{
            name: "Frequency",
            type: "string",
            label: "Frequency",
            values: %{fixed: ["Daily", "Weekly"]},
            widget: "dropdown",
            default: %{value: "", origin: "default"},
            cardinality: "?",
            subscribable: false
          }
        ]
      }
    ]
  }

  describe "stream/1" do
    test "streams over all quality control versions" do
      quality_control = insert(:quality_control)

      TdDfMock.list_templates_by_scope(&Mox.expect/4, "quality_control", {:ok, [@template]})
      TdDdMock.log_start_stream(&Mox.expect/4, 2, :ok)
      TdDdMock.log_progress(&Mox.expect/4, 1, :ok)
      TdDdMock.log_progress(&Mox.expect/4, 1, :ok)

      versioned =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "versioned",
          version: 1
        )

      score_versioned = insert(:score, quality_control_version: versioned)
      insert(:score_event, type: "FAILED", score: score_versioned)

      published =
        insert(:quality_control_version,
          quality_control: quality_control,
          df_type: "quality control",
          status: "published",
          version: 2
        )

      score_published = insert(:score, quality_control_version: published)
      insert(:score_event, type: "SUCCEEDED", score: score_published)

      {:ok, to_index} =
        Repo.transaction(fn ->
          QualityControlVersion
          |> Store.stream()
          |> Enum.to_list()
        end)

      assert Enum.count(to_index) == 2
      assert versioned = Enum.find(to_index, &(&1.id == versioned.id))
      assert versioned.latest_score.id == score_versioned.id
      assert versioned.latest_score.status == "FAILED"
      refute versioned.latest
      assert published = Enum.find(to_index, &(&1.id == published.id))
      assert published.latest
      assert published.latest_score.id == score_published.id
      assert published.latest_score.status == "SUCCEEDED"
    end
  end

  describe "stream/2" do
    test "streams over quality control versions provided a list of ids" do
      TdDfMock.list_templates_by_scope(&Mox.expect/4, "quality_control", {:ok, [@template]})
      TdDdMock.log_start_stream(&Mox.expect/4, 1, :ok)
      TdDdMock.log_progress(&Mox.expect/4, 1, :ok)

      _version1 =
        insert(:quality_control_version,
          quality_control: build(:quality_control),
          df_type: "quality control",
          status: "published",
          version: 2
        )

      version2 =
        insert(:quality_control_version,
          quality_control: build(:quality_control),
          df_type: "quality control",
          status: "published",
          version: 2
        )

      {:ok, [to_index]} =
        Repo.transaction(fn ->
          QualityControlVersion
          |> Store.stream(quality_control_ids: [version2.quality_control_id])
          |> Enum.to_list()
        end)

      assert to_index.id == version2.id
      assert to_index.template == @template
      assert to_index.status == "published"
      assert to_index.latest
    end

    setup do
      Application.put_env(Store, :chunk_size, 10)
      :ok
    end

    @tag sandbox: :shared
    test "streams score_groups" do
      source_id = 8

      %{id: user_id} = CacheHelpers.insert_user()

      %{id: score_group_id} =
        score_group =
        insert(:score_group,
          created_by: user_id,
          df_type: "foo",
          dynamic_content: %{
            "Frequency" => %{"origin" => "user", "value" => "Weekly"},
            "Quality Principle" => %{"origin" => "user", "value" => "Accuracy"}
          }
        )

      Enum.map(1..3, fn _ ->
        insert(:score,
          group: score_group,
          quality_control_version:
            build(:quality_control_version,
              status: "published",
              control_mode: "percentage",
              quality_control: build(:quality_control, source_id: source_id)
            )
        )
      end)

      TdDfMock.list_templates_by_scope(
        &Mox.expect/4,
        "qxe",
        {:ok, [@template_score]}
      )

      TdDdMock.log_start_stream(
        &Mox.expect/4,
        1,
        nil
      )

      TdDdMock.log_progress(
        &Mox.expect/4,
        1,
        nil,
        3
      )

      template = @template_score

      assert [
               %{
                 id: ^score_group_id,
                 created_by: ^user_id,
                 df_type: "foo",
                 template: ^template,
                 dynamic_content: %{
                   "Frequency" => %{"origin" => "user", "value" => "Weekly"},
                   "Quality Principle" => %{"origin" => "user", "value" => "Accuracy"}
                 }
               }
             ] =
               Store.transaction(fn ->
                 ScoreGroup
                 |> Store.stream()
                 |> Enum.to_list()
               end)
    end

    @tag sandbox: :shared
    test "streams score_groups by ids" do
      source_id = 8

      %{id: user_id} = CacheHelpers.insert_user()

      [%{id: score_group_id}, _] =
        Enum.map(1..2, fn _ ->
          score_group =
            insert(:score_group,
              created_by: user_id,
              df_type: "foo",
              dynamic_content: %{
                "Frequency" => %{"origin" => "user", "value" => "Weekly"},
                "Quality Principle" => %{"origin" => "user", "value" => "Accuracy"}
              }
            )

          Enum.map(1..3, fn _ ->
            insert(:score,
              group: score_group,
              quality_control_version:
                build(:quality_control_version,
                  status: "published",
                  control_mode: "percentage",
                  quality_control: build(:quality_control, source_id: source_id)
                )
            )
          end)

          score_group
        end)

      TdDfMock.list_templates_by_scope(
        &Mox.expect/4,
        "qxe",
        {:ok, [@template_score]}
      )

      TdDdMock.log_start_stream(
        &Mox.expect/4,
        1,
        nil
      )

      TdDdMock.log_progress(
        &Mox.expect/4,
        1,
        nil,
        3
      )

      template = @template_score

      assert [
               %{
                 id: ^score_group_id,
                 created_by: ^user_id,
                 df_type: "foo",
                 template: ^template,
                 dynamic_content: %{
                   "Frequency" => %{"origin" => "user", "value" => "Weekly"},
                   "Quality Principle" => %{"origin" => "user", "value" => "Accuracy"}
                 }
               }
             ] =
               Store.transaction(fn ->
                 ScoreGroup
                 |> Store.stream(id: score_group_id)
                 |> Enum.to_list()
               end)
    end
  end
end
