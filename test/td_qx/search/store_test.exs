defmodule TdDd.Search.StoreTest do
  use TdQx.DataCase

  alias TdCluster.TestHelpers.TdDdMock
  alias TdCluster.TestHelpers.TdDfMock
  alias TdQx.Scores.ScoreGroup
  alias TdQx.Search.Store

  @test_template %{
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

  describe "Store.stream/1" do
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
        {:ok, [@test_template]}
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

      template = @test_template

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
        {:ok, [@test_template]}
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

      template = @test_template

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
                 |> Store.stream([score_group_id])
                 |> Enum.to_list()
               end)
    end
  end
end
