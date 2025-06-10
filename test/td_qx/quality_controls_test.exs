defmodule TdQx.QualityControlsTest do
  use TdQx.DataCase

  import TdQx.TestOperators

  alias TdCore.Search.IndexWorkerMock
  alias TdQx.QualityControls
  alias TdQx.QualityControls.ControlProperties
  alias TdQx.QualityControls.QualityControl
  alias TdQx.QualityControls.QualityControlVersion

  describe "quality_controls" do
    @invalid_attrs %{description: nil, domain_ids: nil, name: nil}

    test "list_quality_controls/0 returns all quality_controls" do
      quality_control = insert(:quality_control)
      assert QualityControls.list_quality_controls() ||| [quality_control]
    end

    test "list_quality_control_latest_versions/0 returns all latest version quality_controls" do
      %{id: qc1_id} = qc1 = insert(:quality_control)
      insert(:quality_control_version, quality_control: qc1, version: 1, status: "published")
      insert(:quality_control_version, quality_control: qc1, version: 2, status: "draft")

      %{id: qc2_id} = qc2 = insert(:quality_control)
      insert(:quality_control_version, quality_control: qc2, version: 1, status: "published")

      %{id: qc3_id} = qc3 = insert(:quality_control)
      insert(:quality_control_version, quality_control: qc3, version: 1, status: "versioned")
      insert(:quality_control_version, quality_control: qc3, version: 2, status: "versioned")
      insert(:quality_control_version, quality_control: qc3, version: 3, status: "deprecated")

      assert quality_controls = QualityControls.list_quality_control_latest_versions()

      assert quality_controls
             |> Enum.find(&(&1.id == qc1_id))
             |> Map.get(:latest_version)
             |> Map.take([:version, :status]) == %{
               version: 2,
               status: "draft"
             }

      assert quality_controls
             |> Enum.find(&(&1.id == qc2_id))
             |> Map.get(:latest_version)
             |> Map.take([:version, :status]) == %{
               version: 1,
               status: "published"
             }

      assert quality_controls
             |> Enum.find(&(&1.id == qc3_id))
             |> Map.get(:latest_version)
             |> Map.take([:version, :status]) == %{
               version: 3,
               status: "deprecated"
             }
    end

    test "get_quality_control!/2 returns the quality_control with given id" do
      quality_control = insert(:quality_control)
      assert QualityControls.get_quality_control!(quality_control.id) == quality_control
    end

    test "get_quality_control!/2 enriched the lastest version" do
      quality_control = insert(:quality_control)

      _version_1 =
        insert(:quality_control_version,
          version: 1,
          status: "published",
          quality_control: quality_control
        )

      %{id: qcv_id} =
        insert(:quality_control_version, version: 2, quality_control: quality_control)

      assert %{
               latest_version: %QualityControlVersion{id: ^qcv_id}
             } = QualityControls.get_quality_control!(quality_control.id)
    end

    test "get_quality_control!/2 enriched the published version" do
      quality_control = insert(:quality_control)

      %{id: qcv_id} =
        insert(:quality_control_version,
          version: 1,
          status: "published",
          quality_control: quality_control
        )

      _not_published_version =
        insert(:quality_control_version, version: 2, quality_control: quality_control)

      assert %{
               published_version: %QualityControlVersion{id: ^qcv_id}
             } =
               QualityControls.get_quality_control!(quality_control.id,
                 preload: :published_version
               )
    end

    test "get_quality_control!/2 enrich domains option" do
      %{id: domain_id, external_id: domain_external_id, name: domain_name} =
        CacheHelpers.insert_domain()

      %{id: id} = insert(:quality_control, domain_ids: [domain_id])

      assert %{
               domains: [
                 %{
                   id: ^domain_id,
                   name: ^domain_name,
                   external_id: ^domain_external_id
                 }
               ]
             } = QualityControls.get_quality_control!(id, enrich: [:domains])
    end

    test "delete_quality_control/1 deletes the quality_control" do
      quality_control = insert(:quality_control)
      assert {:ok, %QualityControl{}} = QualityControls.delete_quality_control(quality_control)

      assert_raise Ecto.NoResultsError, fn ->
        QualityControls.get_quality_control!(quality_control.id)
      end
    end

    test "update_quality_control/1 only update active" do
      %{domain_ids: domain_ids, active: true} = quality_control = insert(:quality_control)

      assert {:ok, %{domain_ids: ^domain_ids, active: false}} =
               QualityControls.update_quality_control(quality_control, %{
                 "active" => false,
                 "domains_ids" => [100]
               })
    end
  end

  describe "quality_control_versions" do
    @invalid_attrs %{
      dynamic_content: nil,
      df_type: nil,
      score_criteria: nil,
      control_mode: nil,
      status: nil,
      control_properties: nil,
      version: nil
    }

    test "create_quality_control_version/1 with valid data creates a quality_control_version" do
      quality_control = insert(:quality_control)

      valid_attrs = %{
        name: "some name",
        dynamic_content: %{},
        df_type: "some df_type",
        score_criteria: params_for(:sc_percentage),
        control_mode: "percentage",
        control_properties: params_for(:cp_ratio_params_for)
      }

      assert {:ok, %QualityControlVersion{} = quality_control_version} =
               QualityControls.create_quality_control_version(quality_control, valid_attrs)

      assert quality_control_version.name == "some name"
      assert quality_control_version.dynamic_content == %{}
      assert quality_control_version.df_type == "some df_type"
      assert quality_control_version.status == "draft"
      assert quality_control_version.version == 1
      assert quality_control_version.control_mode == "percentage"
      assert %{percentage: %{goal: 90.0, minimum: 75.0}} = quality_control_version.score_criteria

      assert %{
               ratio: %{
                 resource: %{id: _, type: "data_view"},
                 validation: [
                   %{
                     expressions: [
                       %{shape: "constant", value: %{constant: %{type: "string", value: _}}}
                     ]
                   }
                 ]
               }
             } = quality_control_version.control_properties
    end

    test "create_quality_control_version/1 handles invalid control_mode" do
      quality_control = insert(:quality_control)

      attrs = params_for(:quality_control_version_params_for, control_mode: "invalid_type")

      assert {:error, changeset} =
               QualityControls.create_quality_control_version(quality_control, attrs)

      assert %{score_criteria: %{control_mode: ["invalid"]}} = errors_on(changeset)
    end

    test "create_quality_control_version/1 handles invalid deviation score_criteria" do
      quality_control = insert(:quality_control)

      attrs = params_for(:quality_control_version_params_for, control_mode: "deviation")

      # Goal < 0
      attrs = Map.put(attrs, :score_criteria, %{goal: -1})

      assert {:error, changeset} =
               QualityControls.create_quality_control_version(quality_control, attrs)

      %{score_criteria: %{deviation: error}} = errors_on(changeset)

      assert %{goal: ["must be greater than or equal to 0"]} = error

      # Goal > 100
      attrs = Map.put(attrs, :score_criteria, %{goal: 101})

      assert {:error, changeset} =
               QualityControls.create_quality_control_version(quality_control, attrs)

      %{score_criteria: %{deviation: error}} = errors_on(changeset)

      assert %{goal: ["must be less than or equal to 100"]} = error

      # Maximum > 100
      attrs = Map.put(attrs, :score_criteria, %{goal: 90, maximum: 101})

      assert {:error, changeset} =
               QualityControls.create_quality_control_version(quality_control, attrs)

      %{score_criteria: %{deviation: error}} = errors_on(changeset)

      assert %{maximum: ["must be less than or equal to 100"]} = error

      # Maximum < Goal
      attrs = Map.put(attrs, :score_criteria, %{goal: 50, maximum: 25})

      assert {:error, changeset} =
               QualityControls.create_quality_control_version(quality_control, attrs)

      %{score_criteria: %{deviation: error}} = errors_on(changeset)

      assert %{maximum: ["must be greater than or equal to 50.0"]} = error
    end

    test "create_quality_control_version/1 handles invalid error_count score_criteria" do
      quality_control = insert(:quality_control)

      attrs = params_for(:quality_control_version_params_for, control_mode: "error_count")

      # Goal < 0
      attrs = Map.put(attrs, :score_criteria, %{goal: -1})

      assert {:error, changeset} =
               QualityControls.create_quality_control_version(quality_control, attrs)

      %{score_criteria: %{error_count: error}} = errors_on(changeset)

      assert %{goal: ["must be greater than or equal to 0"]} = error

      # Goal > 100
      attrs = Map.put(attrs, :score_criteria, %{goal: 101})

      assert {:error, changeset} =
               QualityControls.create_quality_control_version(quality_control, attrs)

      %{score_criteria: %{error_count: error}} = errors_on(changeset)

      assert %{goal: ["must be less than or equal to 100"]} = error

      # Maximum > 100
      attrs = Map.put(attrs, :score_criteria, %{goal: 90, maximum: 101})

      assert {:error, changeset} =
               QualityControls.create_quality_control_version(quality_control, attrs)

      %{score_criteria: %{error_count: error}} = errors_on(changeset)

      assert %{maximum: ["must be less than or equal to 100"]} = error

      # Maximum < Goal
      attrs = Map.put(attrs, :score_criteria, %{goal: 50, maximum: 25})

      assert {:error, changeset} =
               QualityControls.create_quality_control_version(quality_control, attrs)

      %{score_criteria: %{error_count: error}} = errors_on(changeset)

      assert %{maximum: ["must be greater than or equal to 50.0"]} = error
    end

    test "create_quality_control_version/1 handles invalid count score_criteria" do
      quality_control = insert(:quality_control)

      attrs =
        params_for(:quality_control_version_params_for, control_mode: "count")

      # Goal < 0
      attrs = Map.put(attrs, :score_criteria, %{goal: -1})

      assert {:error, changeset} =
               QualityControls.create_quality_control_version(quality_control, attrs)

      %{score_criteria: %{count: error}} = errors_on(changeset)

      assert %{goal: ["must be greater than or equal to 0"]} = error

      # Maximum < Goal
      attrs = Map.put(attrs, :score_criteria, %{goal: 50, maximum: 10})

      assert {:error, changeset} =
               QualityControls.create_quality_control_version(quality_control, attrs)

      %{score_criteria: %{count: error}} = errors_on(changeset)

      assert %{maximum: ["must be greater than or equal to 50"]} = error
    end

    test "create_quality_control_version/1 handles invalid percentage score_criteria" do
      quality_control = insert(:quality_control)

      attrs = params_for(:quality_control_version_params_for, control_mode: "percentage")

      # Goal < 0
      attrs = Map.put(attrs, :score_criteria, %{goal: -1})

      assert {:error, changeset} =
               QualityControls.create_quality_control_version(quality_control, attrs)

      %{score_criteria: %{percentage: error}} = errors_on(changeset)

      assert %{goal: ["must be greater than or equal to 0"]} = error

      # Goal > 100
      attrs = Map.put(attrs, :score_criteria, %{goal: 101})

      assert {:error, changeset} =
               QualityControls.create_quality_control_version(quality_control, attrs)

      %{score_criteria: %{percentage: error}} = errors_on(changeset)

      assert %{goal: ["must be less than or equal to 100"]} = error

      # Minimum < 0
      attrs = Map.put(attrs, :score_criteria, %{goal: 90, minimum: -1})

      assert {:error, changeset} =
               QualityControls.create_quality_control_version(quality_control, attrs)

      %{score_criteria: %{percentage: error}} = errors_on(changeset)

      assert %{minimum: ["must be greater than or equal to 0"]} = error

      # Minimum > Goal
      attrs = Map.put(attrs, :score_criteria, %{goal: 50, minimum: 75})

      assert {:error, changeset} =
               QualityControls.create_quality_control_version(quality_control, attrs)

      %{score_criteria: %{percentage: error}} = errors_on(changeset)

      assert %{minimum: ["must be less than or equal to 50.0"]} = error
    end

    test "create_quality_control_version/1 with invalid data returns error changeset" do
      quality_control = insert(:quality_control)

      assert {:error, %Ecto.Changeset{}} =
               QualityControls.create_quality_control_version(quality_control, @invalid_attrs)
    end
  end

  describe "list_quality_control_versions/1" do
    test "list_version with scores in draft" do
      {_quality_control, version_draft} = create_quality_control("draft", 1)
      score_succeeded = create_score(version_draft, "SUCCEEDED", "draft")

      score_failed =
        create_score(version_draft, "FAILED", "draft", score_succeeded.execution_timestamp)

      [version] =
        QualityControls.list_quality_control_versions()

      assert version.id == version_draft.id
      assert version.latest_score.id == score_failed.id
      assert is_nil(version.final_score.id)
    end

    test "list_version with scores in draft and not loaded in published versions" do
      {quality_control, version_published} = create_quality_control("published", 1)

      version_draft = create_quality_control_version(quality_control, "draft", 2)

      score_succeeded = create_score(version_draft, "SUCCEEDED", "draft")

      score_failed =
        create_score(version_draft, "FAILED", "draft", score_succeeded.execution_timestamp)

      versions =
        QualityControls.list_quality_control_versions()

      assert [result_version_draft] =
               Enum.filter(versions, &(&1.id == version_draft.id))

      assert result_version_draft.latest_score.id == score_failed.id
      assert is_nil(result_version_draft.final_score.id)

      assert [result_version_published] =
               Enum.filter(versions, &(&1.id == version_published.id))

      assert is_nil(result_version_published.latest_score)
      assert is_nil(result_version_published.final_score.id)
    end

    test "list_version with scores in draft and published with the same version" do
      {_quality_control, version_published} = create_quality_control("published", 1)
      score_draft = create_score(version_published, "FAILED", "draft")

      [version] = QualityControls.list_quality_control_versions()
      assert version.latest_score.id == score_draft.id
      assert is_nil(version.final_score.id)

      score_succeeded =
        create_score(version_published, "SUCCEEDED", "published", score_draft.execution_timestamp)

      [version] = QualityControls.list_quality_control_versions()

      assert version.latest_score.id == score_succeeded.id
      assert version.final_score.id == score_succeeded.id
    end

    test "list_version with scores in published and versioned" do
      {quality_control, version_versioned} = create_quality_control("versioned", 1)
      version_published = create_quality_control_version(quality_control, "published", 2)

      score_versioned = create_score(version_versioned, "FAILED", "published")

      versiones = QualityControls.list_quality_control_versions()

      assert [version] =
               Enum.filter(versiones, &(&1.id == version_versioned.id))

      assert version.latest_score.id == score_versioned.id
      assert version.final_score.id == score_versioned.id

      assert [result_version_published] =
               Enum.filter(versiones, &(&1.id == version_published.id))

      assert is_nil(result_version_published.latest_score)
      assert result_version_published.final_score.id == score_versioned.id

      score_succeeded =
        create_score(
          version_published,
          "SUCCEEDED",
          "published",
          score_versioned.execution_timestamp
        )

      versiones = QualityControls.list_quality_control_versions()

      assert [version] =
               Enum.filter(versiones, &(&1.id == version_published.id))

      assert version.latest_score.id == score_succeeded.id
      assert version.final_score.id == score_succeeded.id
    end

    test "list_version with scores in deprecated and versioned" do
      {quality_control, version_versioned} = create_quality_control("versioned", 1)
      deprecated = create_quality_control_version(quality_control, "deprecated", 2)

      score_versioned = create_score(version_versioned, "FAILED", "published")

      versiones = QualityControls.list_quality_control_versions()

      assert [version] =
               Enum.filter(versiones, &(&1.id == version_versioned.id))

      assert version.latest_score.id == score_versioned.id
      assert version.final_score.id == score_versioned.id

      assert [result_version_deprecated] =
               Enum.filter(versiones, &(&1.id == deprecated.id))

      assert is_nil(result_version_deprecated.latest_score)
      assert result_version_deprecated.final_score.id == score_versioned.id

      score_succeeded =
        create_score(
          deprecated,
          "SUCCEEDED",
          "published",
          score_versioned.execution_timestamp
        )

      versiones = QualityControls.list_quality_control_versions()

      assert [version] =
               Enum.filter(versiones, &(&1.id == deprecated.id))

      assert version.latest_score.id == score_succeeded.id
      assert version.final_score.id == score_succeeded.id
    end

    test "lists versions by quality_control_id specifying latest version" do
      {quality_control_draft, version_draft} = create_quality_control("draft", 1)

      assert [draft_version] =
               QualityControls.list_quality_control_versions(
                 quality_control_ids: [quality_control_draft.id]
               )

      assert draft_version.id == version_draft.id
      assert draft_version.latest
      assert draft_version.version == 1
      assert draft_version.status == "draft"
    end
  end

  describe "get_quality_control_version/3" do
    setup do
      domain = %{id: domain_id} = CacheHelpers.insert_domain()
      quality_control = insert(:quality_control, domain_ids: [domain_id])

      versioned =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "versioned",
          version: 1
        )

      published =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "published",
          version: 2
        )

      [quality_control: quality_control, versions: [versioned, published], domain: domain]
    end

    test "gets quality control version with preloaded quality control by default", %{
      quality_control: quality_control,
      versions: [versioned, published]
    } do
      assert %QualityControlVersion{} =
               version = QualityControls.get_quality_control_version(quality_control.id, 1)

      assert version.id == versioned.id
      assert version.version == 1
      assert version.status == "versioned"
      assert version.quality_control.id == quality_control.id
      refute version.latest

      assert %QualityControlVersion{} =
               version = QualityControls.get_quality_control_version(quality_control.id, 2)

      assert version.id == published.id
      assert version.version == 2
      assert version.status == "published"
      assert version.quality_control.id == quality_control.id
      assert version.latest
    end

    test "gets quality control version with preloads and enriched attributes", %{
      versions: [versioned | _tail],
      domain: domain
    } do
      assert %QualityControlVersion{
               quality_control: %QualityControl{domains: [enriched_domain]},
               control_properties: %ControlProperties{} = control_properties
             } =
               QualityControls.get_quality_control_version(
                 versioned.quality_control_id,
                 versioned.version,
                 enrich: [:domains, :control_properties],
                 preload: [quality_control: :versions]
               )

      assert [Map.take(enriched_domain, [:id, :name, :external_id])] == [
               Map.take(domain, [:id, :name, :external_id])
             ]

      refute versioned.control_properties.ratio.resource.embedded
      assert control_properties.ratio.resource.embedded
    end

    test "gets quality control version with versions preload ordered desc", %{
      versions: [versioned | _tail]
    } do
      assert %QualityControlVersion{quality_control: %QualityControl{versions: versions}} =
               QualityControls.get_quality_control_version(
                 versioned.quality_control_id,
                 versioned.version,
                 preload: [quality_control: {:versions, :desc}]
               )

      assert [published, versioned] = versions
      assert published.version == 2
      assert versioned.version == 1
    end
  end

  describe "delete_quality_control_version/1" do
    setup do
      IndexWorkerMock.clear()
      :ok
    end

    test "deletes quality control when the version to delete is the only one" do
      quality_control_version =
        %{quality_control: %{id: id}} =
        insert(:quality_control_version,
          status: "draft",
          quality_control: insert(:quality_control)
        )

      assert {:ok, %QualityControl{id: ^id}} =
               QualityControls.delete_quality_control_version(quality_control_version)

      refute Repo.get(QualityControl, id)
      refute Repo.get(QualityControlVersion, quality_control_version.id)

      assert IndexWorkerMock.calls() == [
               {:delete, :quality_control_versions, [quality_control_version.id]}
             ]
    end

    test "deletes quality control version when the quality control has more versions" do
      quality_control = insert(:quality_control)

      versioned =
        insert(:quality_control_version,
          status: "versioned",
          quality_control: quality_control,
          version: 1
        )

      draft =
        %{id: id} =
        insert(:quality_control_version,
          status: "draft",
          quality_control: quality_control,
          version: 2
        )

      assert {:ok, %QualityControlVersion{id: ^id}} =
               QualityControls.delete_quality_control_version(draft)

      assert Repo.get(QualityControl, quality_control.id)
      assert Repo.get(QualityControlVersion, versioned.id)
      refute Repo.get(QualityControlVersion, draft.id)

      assert IndexWorkerMock.calls() == [{:delete, :quality_control_versions, [draft.id]}]
    end

    test "returns forbidden when quality control version is not in draft" do
      quality_control = insert(:quality_control)

      versioned =
        insert(:quality_control_version,
          status: "versioned",
          quality_control: quality_control,
          version: 1
        )

      assert {:error, :forbidden} = QualityControls.delete_quality_control_version(versioned)
      assert Repo.get(QualityControl, quality_control.id)
      assert Repo.get(QualityControlVersion, versioned.id)
    end
  end

  describe "get_quality_control_with_latest_result/1" do
    test "returns an empty map when there are no scores" do
      quality_control = insert(:quality_control)

      assert {:last_execution_result, %{}} ==
               QualityControls.get_quality_control_with_latest_result(%{id: quality_control.id})
    end

    Enum.each(["FAILED", "SUCCEEDED"], fn loop_status ->
      test "returns the latest executed result (#{loop_status}) when scores are available" do
        status = unquote(loop_status)

        {%{id: quality_control_id}, version} = create_quality_control("published", 1)

        %{last_execution_result: last_execution_result} =
          create_score(version, status, "published", ~U[2023-05-02 12:00:00Z])

        {:last_execution_result, received_last_execution_result} =
          QualityControls.get_quality_control_with_latest_result(%{id: quality_control_id})

        assert received_last_execution_result == last_execution_result
      end
    end)

    Enum.each(
      ["QUEUED", "TIMEOUT", "PENDING", "STARTED", "INFO", "WARNING"],
      fn loop_status ->
        test "return empty map with invalid score status: #{loop_status}" do
          status = unquote(loop_status)

          {%{id: quality_control_id}, version} = create_quality_control("published", 1)
          create_score(version, status, "published")

          assert {:last_execution_result, %{}} ==
                   QualityControls.get_quality_control_with_latest_result(%{
                     id: quality_control_id
                   })
        end
      end
    )
  end

  defp create_score(version, type_event, quality_control_status),
    do: create_score(version, type_event, quality_control_status, DateTime.utc_now())

  defp create_score(version, type_event, quality_control_status, execution_timestamp) do
    statuses = ["PENDING"] ++ ensure_list(type_event)
    %{id: group_id} = insert(:score_group)

    last_status = List.last(statuses)

    score_result_detail =
      if last_status == "ERROR", do: %{error: "Error in the event"}, else: %{"foo" => "manchu"}

    score =
      insert(:score,
        quality_control_version: version,
        quality_control_status: quality_control_status,
        execution_timestamp: DateTime.add(execution_timestamp, 60, :second),
        status: last_status,
        group_id: group_id,
        latest_event_message: "Last status received: #{last_status}",
        details: score_result_detail
      )

    events =
      Enum.map(
        statuses,
        &insert(:score_event,
          message: "Last status received: #{last_status}",
          type: &1,
          score: score
        )
      )

    last_execution_result =
      events
      |> List.last()
      |> Map.get(:score)
      |> Map.take([
        :id,
        :group_id,
        :quality_control_version_id,
        :latest_event_message,
        :execution_timestamp,
        :type,
        :details,
        :status
      ])

    score
    |> Map.put(:events, events)
    |> Map.put(:last_execution_result, last_execution_result)
  end

  defp ensure_list(value) when is_list(value), do: value
  defp ensure_list(value) when is_binary(value), do: [value]
  defp ensure_list(nil), do: []

  defp create_quality_control(qcv_status, qcv_version) do
    qc = insert(:quality_control)
    qvc = create_quality_control_version(qc, qcv_status, qcv_version)
    {qc, qvc}
  end

  defp create_quality_control_version(qc, status, version) do
    insert(:quality_control_version,
      quality_control: qc,
      status: status,
      version: version
    )
  end
end
