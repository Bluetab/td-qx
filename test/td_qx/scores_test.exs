defmodule TdQx.ScoresTest do
  use TdQx.DataCase

  import TdQx.TestOperators

  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdCluster.TestHelpers.TdDfMock
  alias TdCore.Search.IndexWorkerMock
  alias TdQx.QualityControls.QualityControlVersion
  alias TdQx.Repo
  alias TdQx.Scores
  alias TdQx.Scores.Score
  alias TdQx.Scores.ScoreEvent

  @audit_stream TdCache.Audit.stream()

  describe "list_score_groups/1" do
    test "returns all score_groups" do
      groups = for _ <- 1..3, do: insert(:score_group)

      assert groups ||| Scores.list_score_groups()
    end

    test "filters by created_by" do
      user_id = random_integer()
      user_groups = for _ <- 1..3, do: insert(:score_group, created_by: user_id)

      for _ <- 1..3, do: insert(:score_group)

      assert user_groups ||| Scores.list_score_groups(created_by: user_id)
    end

    test "preloads scores" do
      score_group = insert(:score_group)

      scores = for _ <- 1..3, do: insert(:score, group: score_group)

      assert [
               %{
                 scores: result_scores
               }
             ] = Scores.list_score_groups(preload: :scores)

      assert scores ||| result_scores
    end

    test "preloads score's statuses and events" do
      score_group = insert(:score_group)

      score = insert(:score, group: score_group)
      %{id: event_id} = insert(:score_event, type: "PENDING", score: score)

      assert [
               %{
                 scores: [
                   %{
                     status: "PENDING",
                     events: [%{id: ^event_id}]
                   }
                 ]
               }
             ] = Scores.list_score_groups(preload: [scores: [:status, :events]])
    end
  end

  describe "get_score_group/2" do
    test "returns score_group by id" do
      group = insert(:score_group)

      assert group <~> Scores.get_score_group(group.id)
    end

    test "preloads scores and events" do
      group = insert(:score_group)
      score = insert(:score, group: group)
      event = insert(:score_event, type: "PENDING", score: score, message: nil)

      result =
        Scores.get_score_group(group.id, preload: [scores: [:status, :events]])

      assert group <~> result

      assert [score] ||| result.scores

      [%{events: result_events, status: "PENDING"}] = result.scores
      assert [event] ||| result_events
    end
  end

  describe "aggregate_status_summary/1" do
    test "aggregates scores status into summary on each group" do
      score_group = insert(:score_group)

      insert(:score_event, type: "PENDING", score: build(:score, group: score_group))
      insert(:score_event, type: "PENDING", score: build(:score, group: score_group))
      insert(:score_event, type: "STARTED", score: build(:score, group: score_group))
      insert(:score_event, type: "QUEUED", score: build(:score, group: score_group))
      insert(:score_event, type: "TIMEOUT", score: build(:score, group: score_group))
      insert(:score_event, type: "FAILED", score: build(:score, group: score_group))
      insert(:score_event, type: "SUCCEEDED", score: build(:score, group: score_group))

      [score_group] =
        [preload: [scores: :status]]
        |> Scores.list_score_groups()
        |> Scores.aggregate_status_summary()

      assert %{
               scores: nil,
               status_summary: %{
                 "PENDING" => 2,
                 "STARTED" => 1,
                 "QUEUED" => 1,
                 "TIMEOUT" => 1,
                 "FAILED" => 1,
                 "SUCCEEDED" => 1
               }
             } = score_group
    end
  end

  describe "create_score_group/2" do
    setup do
      IndexWorkerMock.clear()

      # Clean up audit stream before each test
      Redix.command!(["DEL", @audit_stream])

      on_exit(fn ->
        Redix.command!(["DEL", @audit_stream])
      end)

      :ok
    end

    defp read_audit_events(stream \\ @audit_stream, count \\ 1) do
      Stream.read(:redix, stream, count: count, transform: true)
    end

    test "creates a score_group and it's scores" do
      template_name = "type"
      created_by = 10

      valid_attrs = %{
        dynamic_content: %{},
        df_type: template_name,
        created_by: created_by
      }

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: []}}
      )

      quality_control_version_ids =
        for _ <- 1..5,
            do:
              insert(:quality_control_version,
                status: "published",
                quality_control: build(:quality_control)
              ).id

      assert {:ok,
              %{
                score_group: %{
                  id: score_group_id,
                  df_type: ^template_name,
                  created_by: ^created_by
                }
              }} = Scores.create_score_group(quality_control_version_ids, valid_attrs)

      %{scores: scores} = Scores.get_score_group(score_group_id, preload: [scores: :status])

      assert length(scores) == 5
      assert Enum.all?(scores, &(&1.status == "PENDING"))

      assert IndexWorkerMock.calls() == [
               {:reindex, :quality_control_versions, [{:ids, quality_control_version_ids}]},
               {:reindex, :score_groups, [{:id, score_group_id}]}
             ]
    end

    test "publishes audit event for score_group_created" do
      template_name = "execution_type"
      created_by = 123

      valid_attrs = %{
        dynamic_content: %{"param" => %{"value" => "value", "origin" => "user"}},
        df_type: template_name,
        created_by: created_by
      }

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: []}}
      )

      quality_control_version_ids =
        for _ <- 1..3,
            do:
              insert(:quality_control_version,
                status: "published",
                quality_control: build(:quality_control)
              ).id

      assert {:ok, %{score_group: %{id: score_group_id}}} =
               Scores.create_score_group(quality_control_version_ids, valid_attrs)

      # Read all events (1 score_group_created + 3 score_created + 3 score_event_created)
      {:ok, events} = read_audit_events(@audit_stream, 7)
      assert length(events) == 7

      # Find the score_group_created event
      group_event = Enum.find(events, &(&1.event == "score_group_created"))

      assert group_event.resource_type == "score_group"
      assert group_event.resource_id == to_string(score_group_id)

      payload = Jason.decode!(group_event.payload)
      assert payload["df_type"] == template_name
      assert payload["created_by"] == created_by
      assert payload["dynamic_content"] == %{"param" => %{"origin" => "user", "value" => "value"}}
    end

    test "publishes audit events for all scores created" do
      template_name = "type"
      created_by = 456

      valid_attrs = %{
        dynamic_content: %{},
        df_type: template_name,
        created_by: created_by
      }

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: []}}
      )

      quality_controls =
        for _ <- 1..3,
            do: insert(:quality_control, domain_ids: [1], source_id: 10)

      quality_control_version_ids =
        Enum.map(quality_controls, fn qc ->
          insert(:quality_control_version,
            status: "published",
            quality_control: qc
          ).id
        end)

      assert {:ok, %{score_group: %{id: score_group_id}}} =
               Scores.create_score_group(quality_control_version_ids, valid_attrs)

      # Read all events (1 score_group_created + 3 score_created + 3 score_event_created)
      {:ok, events} = read_audit_events(@audit_stream, 7)
      assert length(events) == 7

      # Find all score_created events
      score_events = Enum.filter(events, &(&1.event == "score_created"))
      assert length(score_events) == 3

      # Verify each score event
      %{scores: scores} = Scores.get_score_group(score_group_id, preload: [scores: :status])

      for event <- score_events do
        assert event.resource_type == "score"
        assert event.resource_id in Enum.map(scores, &to_string(&1.id))

        payload = Jason.decode!(event.payload)
        assert payload["group_id"] == score_group_id
        assert payload["quality_control_version_id"] in quality_control_version_ids
        assert payload["quality_control_id"] in Enum.map(quality_controls, & &1.id)
      end
    end

    test "publishes audit events for all score_events created" do
      template_name = "type"
      created_by = 456

      valid_attrs = %{
        dynamic_content: %{},
        df_type: template_name,
        created_by: created_by
      }

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: []}}
      )

      quality_control_versions =
        for _ <- 1..3,
            do:
              insert(:quality_control_version,
                status: "published",
                quality_control: build(:quality_control)
              )

      quality_control_version_ids = Enum.map(quality_control_versions, & &1.id)
      quality_controls = Enum.map(quality_control_versions, & &1.quality_control)

      assert {:ok, %{score_group: %{id: score_group_id}}} =
               Scores.create_score_group(quality_control_version_ids, valid_attrs)

      # Read all events (1 score_group_created + 3 score_created + 3 score_event_created)
      {:ok, events} = read_audit_events(@audit_stream, 7)
      assert length(events) == 7

      # Find all score_event_created events
      score_event_events = Enum.filter(events, &(&1.event == "score_event_created"))
      assert length(score_event_events) == 3

      # Verify each score_event_event
      %{scores: scores} = Scores.get_score_group(score_group_id, preload: [scores: :status])

      for event <- score_event_events do
        assert event.resource_type == "score"
        assert event.resource_id in Enum.map(scores, &to_string(&1.id))

        payload = Jason.decode!(event.payload)
        assert payload["score_id"] in Enum.map(scores, & &1.id)
        assert payload["type"] == "PENDING"
        assert payload["quality_control_id"] in Enum.map(quality_controls, & &1.id)
        assert payload["quality_control_version_id"] in quality_control_version_ids

        assert payload["domain_ids"] ==
                 quality_controls |> Enum.flat_map(& &1.domain_ids) |> Enum.uniq()
      end
    end

    test "returns error when quality_control_version_ids is empty" do
      valid_attrs = %{
        dynamic_content: %{},
        df_type: "type",
        created_by: 123
      }

      assert {:error, :unprocessable_entity} =
               Scores.create_score_group([], valid_attrs)

      # Verify no audit events were published
      {:ok, []} = read_audit_events()
    end

    test "returns error when score_group validation fails" do
      template_name = "type"

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: []}}
      )

      quality_control_version_ids = [
        insert(:quality_control_version, quality_control: build(:quality_control)).id
      ]

      # Missing required fields
      invalid_attrs = %{dynamic_content: %{}, df_type: template_name}

      assert {:error, :score_group, %{errors: errors}, %{}} =
               Scores.create_score_group(quality_control_version_ids, invalid_attrs)

      assert errors[:created_by] == {"can't be blank", [validation: :required]}

      {:ok, []} = read_audit_events()
    end

    test "returns error when dynamic_content validation fails" do
      template_name = "type"
      created_by = 123

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok,
         %{
           content: [
             %{
               "name" => "field",
               "fields" => [%{"name" => "required_field", "cardinality" => "1"}]
             }
           ]
         }}
      )

      quality_control_version_ids = [
        insert(:quality_control_version, quality_control: build(:quality_control)).id
      ]

      invalid_attrs = %{
        dynamic_content: %{},
        df_type: template_name,
        created_by: created_by
      }

      assert {:error, :score_group, %{errors: errors}, %{}} =
               Scores.create_score_group(quality_control_version_ids, invalid_attrs)

      assert errors[:dynamic_content] ==
               {"required_field: can't be blank",
                [required_field: {"can't be blank", [validation: :required]}]}

      # Verify no audit events were published on error
      {:ok, []} = read_audit_events()
    end

    test "creates scores with PENDING events" do
      template_name = "type"
      created_by = 789

      valid_attrs = %{
        dynamic_content: %{},
        df_type: template_name,
        created_by: created_by
      }

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: []}}
      )

      quality_control_version_ids =
        for _ <- 1..2,
            do:
              insert(:quality_control_version,
                status: "published",
                quality_control: build(:quality_control)
              ).id

      assert {:ok, %{score_group: %{id: score_group_id}}} =
               Scores.create_score_group(quality_control_version_ids, valid_attrs)

      %{scores: scores} = Scores.get_score_group(score_group_id, preload: [scores: :events])

      assert length(scores) == 2

      for score <- scores do
        assert length(score.events) == 1
        [event] = score.events
        assert event.type == "PENDING"
      end
    end

    test "calls reindex for quality_control_versions and score_groups" do
      template_name = "type"

      valid_attrs = %{
        dynamic_content: %{},
        df_type: template_name,
        created_by: 100
      }

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: []}}
      )

      quality_control_version_ids =
        for _ <- 1..3,
            do:
              insert(:quality_control_version,
                status: "published",
                quality_control: build(:quality_control)
              ).id

      IndexWorkerMock.clear()

      assert {:ok, %{score_group: %{id: score_group_id}}} =
               Scores.create_score_group(quality_control_version_ids, valid_attrs)

      assert IndexWorkerMock.calls() == [
               {:reindex, :quality_control_versions, [{:ids, quality_control_version_ids}]},
               {:reindex, :score_groups, [{:id, score_group_id}]}
             ]
    end

    test "handles single quality_control_version" do
      template_name = "type"

      valid_attrs = %{
        dynamic_content: %{},
        df_type: template_name,
        created_by: 200
      }

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: []}}
      )

      quality_control_version_id =
        insert(:quality_control_version,
          status: "published",
          quality_control: build(:quality_control)
        ).id

      assert {:ok, %{score_group: %{id: score_group_id}}} =
               Scores.create_score_group([quality_control_version_id], valid_attrs)

      %{scores: scores} = Scores.get_score_group(score_group_id, preload: [scores: :status])
      assert length(scores) == 1

      # Verify audit events (1 score_group + 1 score)
      {:ok, events} = read_audit_events(@audit_stream, 2)
      assert length(events) == 2

      group_events = Enum.filter(events, &(&1.event == "score_group_created"))
      score_events = Enum.filter(events, &(&1.event == "score_created"))

      assert length(group_events) == 1
      assert length(score_events) == 1
    end
  end

  describe "list_scores/2" do
    test "returns all scores" do
      scores = for _ <- 1..3, do: insert(:score)

      assert scores ||| Scores.list_scores()
    end

    test "preloads events and status" do
      score1 = insert(:score)
      score1_event_pending = insert(:score_event, type: "PENDING", score: score1)
      score1_event_queued = insert(:score_event, type: "QUEUED", score: score1)

      score2 = insert(:score)
      score2_event_pending = insert(:score_event, type: "PENDING", score: score2)

      [listed_score1, listed_score2] =
        Scores.list_scores(preload: [:status, :events, :quality_control_version])

      assert "QUEUED" = listed_score1.status
      assert "PENDING" = listed_score2.status

      assert [score1_event_pending, score1_event_queued] ||| listed_score1.events
      assert [score2_event_pending] ||| listed_score2.events
    end

    test "filters by status" do
      insert(:score_event, type: "PENDING")
      %{score: %{id: score_id}} = insert(:score_event, type: "QUEUED")
      insert(:score_event, type: "COMPLETED")

      assert [
               %{id: ^score_id, status: "QUEUED"}
             ] = Scores.list_scores(status: "QUEUED")
    end

    test "filters by sources" do
      source_id = 8

      score =
        insert(:score,
          quality_control_version:
            build(:quality_control_version,
              status: "published",
              quality_control: build(:quality_control, source_id: source_id)
            )
        )

      _another_score =
        insert(:score,
          quality_control_version:
            build(:quality_control_version,
              quality_control: build(:quality_control, source_id: source_id + 1)
            )
        )

      assert [score] ||| Scores.list_scores(sources: [source_id])
    end

    test "filters by quality_control_id" do
      %{id: score_id, quality_control_version: %{quality_control_id: quality_control_id}} =
        insert(:score)

      insert(:score)
      insert(:score)

      assert [
               %{id: ^score_id}
             ] = Scores.list_scores(quality_control_id: quality_control_id)
    end
  end

  describe "get_score/2" do
    test "returns a score" do
      score = insert(:score)

      assert score <~> Scores.get_score(score.id)
    end

    test "preloads events" do
      score = insert(:score)
      event = insert(:score_event, score: score)

      result = Scores.get_score(score.id, preload: :events)
      assert score <~> result
      assert [event] ||| result.events
    end

    test "preloads score's status" do
      score = insert(:score)
      insert(:score_event, type: "PENDING", score: score)
      insert(:score_event, type: "QUEUED", score: score)

      assert %{status: "QUEUED"} = Scores.get_score(score.id, preload: :status)
    end

    test "INFO and WARNING events does not affect status" do
      score = insert(:score)

      insert(:score_event, type: "QUEUED", score: score)
      assert %{status: "QUEUED"} = Scores.get_score(score.id, preload: :status)

      insert(:score_event, type: "STARTED", score: score)
      assert %{status: "STARTED"} = Scores.get_score(score.id, preload: :status)

      insert(:score_event, type: "INFO", score: score)
      assert %{status: "STARTED"} = Scores.get_score(score.id, preload: :status)

      insert(:score_event, type: "WARNING", score: score)
      assert %{status: "STARTED"} = Scores.get_score(score.id, preload: :status)
    end
  end

  describe "update_scores_quality_control_properties/1" do
    setup do
      Redix.command!(["DEL", @audit_stream])

      on_exit(fn ->
        Redix.command!(["DEL", @audit_stream])
      end)

      :ok
    end

    for status <- QualityControlVersion.valid_statuses() do
      @tag [status: status]
      test "updates quality_control_status for status #{status}", %{status: status} do
        score =
          insert(:score,
            quality_control_version:
              build(:quality_control_version,
                status: status,
                quality_control: build(:quality_control)
              )
          )

        assert %{quality_control_status: nil} = Scores.get_score(score.id)

        Scores.update_scores_quality_control_properties()

        assert %{quality_control_status: ^status} = Scores.get_score(score.id)
        {:ok, [event]} = read_audit_events(@audit_stream, 1)
        assert event.event == "score_updated"
        assert event.resource_type == "score"
        assert event.resource_id == to_string(score.id)
        payload = Jason.decode!(event.payload)
        assert payload["quality_control_status"] == status
      end
    end

    for {control_mode, score_type} <- [
          {"deviation", "ratio"},
          {"percentage", "ratio"},
          {"error_count", "ratio"},
          {"count", "count"}
        ] do
      @tag [control_mode: control_mode, score_type: score_type]
      test "updates score_type for control_mode #{control_mode}", %{
        control_mode: control_mode,
        score_type: score_type
      } do
        score =
          insert(:score,
            quality_control_version:
              build(:quality_control_version,
                control_mode: control_mode,
                quality_control: build(:quality_control)
              )
          )

        assert %{score_type: nil} = Scores.get_score(score.id)

        Scores.update_scores_quality_control_properties()

        assert %{score_type: ^score_type} = Scores.get_score(score.id)
        {:ok, [event]} = read_audit_events(@audit_stream, 1)
        assert event.event == "score_updated"
        assert event.resource_type == "score"
        assert event.resource_id == to_string(score.id)
        payload = Jason.decode!(event.payload)
        assert payload["score_type"] == score_type
      end
    end

    test "filters by source_id and status" do
      source_id = 8

      score1 =
        insert(:score,
          quality_control_version:
            build(:quality_control_version,
              control_mode: "percentage",
              status: "draft",
              quality_control: build(:quality_control, source_id: source_id)
            )
        )

      insert(:score_event, type: "PENDING", score: score1)

      score2 =
        insert(:score,
          quality_control_version:
            build(:quality_control_version,
              control_mode: "percentage",
              status: "draft",
              quality_control: build(:quality_control, source_id: source_id)
            )
        )

      insert(:score_event, type: "QUEUED", score: score2)

      score3 = insert(:score)

      assert %{score_type: nil, quality_control_status: nil} = Scores.get_score(score1.id)
      assert %{score_type: nil, quality_control_status: nil} = Scores.get_score(score2.id)
      assert %{score_type: nil, quality_control_status: nil} = Scores.get_score(score3.id)

      Scores.update_scores_quality_control_properties(status: "PENDING", sources: [source_id])

      assert %{score_type: "ratio", quality_control_status: "draft"} = Scores.get_score(score1.id)
      assert %{score_type: nil, quality_control_status: nil} = Scores.get_score(score2.id)
      assert %{score_type: nil, quality_control_status: nil} = Scores.get_score(score3.id)

      Scores.update_scores_quality_control_properties(sources: [source_id])

      assert %{score_type: "ratio", quality_control_status: "draft"} = Scores.get_score(score1.id)
      assert %{score_type: "ratio", quality_control_status: "draft"} = Scores.get_score(score2.id)
      assert %{score_type: nil, quality_control_status: nil} = Scores.get_score(score3.id)

      assert {:ok, events} = read_audit_events(@audit_stream, 3)
      assert length(events) == 3
      assert Enum.all?(events, &(&1.event == "score_updated"))
      assert Enum.all?(events, &(&1.resource_type == "score"))

      for event <- events do
        payload = Jason.decode!(event.payload)
        assert payload["score_type"] == "ratio"
        assert payload["quality_control_status"] == "draft"
      end
    end
  end

  describe "updated_succeeded_score/2" do
    setup do
      IndexWorkerMock.clear()

      Redix.command!(["DEL", @audit_stream])

      on_exit(fn ->
        Redix.command!(["DEL", @audit_stream])
      end)

      :ok
    end

    test "parses the result into score_content and set status as SUCCEEDED" do
      %{id: group_id} = group = insert(:score_group)

      %{quality_control_version_id: quality_control_version_id} =
        score = insert(:score, score_type: "ratio", group_id: group_id, group: group)

      insert(:score_event, type: "STARTED", score: score)

      params = %{
        "execution_timestamp" => "2024-11-18 15:34:21.438113Z",
        "message" => "Execution completed",
        "result" => %{
          "total_count" => [[10]],
          "validation_count" => [[1]]
        },
        "details" => %{"foo" => "bar"}
      }

      assert {:ok,
              %{
                score: %{
                  score_content: %{
                    ratio: %{
                      total_count: 10,
                      validation_count: 1
                    }
                  },
                  execution_timestamp: ~U[2024-11-18 15:34:21.438113Z],
                  details: %{"foo" => "bar"}
                }
              }} = Scores.updated_succeeded_score(score, params)

      assert %{status: "SUCCEEDED"} = Scores.get_score(score.id, preload: :status)

      assert IndexWorkerMock.calls() == [
               {:reindex, :quality_control_versions, [ids: quality_control_version_id]}
             ]

      {:ok, events} = read_audit_events(@audit_stream, 2)
      assert length(events) == 2

      event = Enum.find(events, &(&1.event == "score_status_updated"))
      assert event.event == "score_status_updated"
      assert event.resource_type == "score"
      assert event.resource_id == to_string(score.id)
      payload = Jason.decode!(event.payload)
      assert payload["status"] == "succeeded"
      assert payload["latest_event_message"] == "Execution completed"

      event = Enum.find(events, &(&1.event == "score_event_created"))
      payload = Jason.decode!(event.payload)
      assert event.resource_type == "score"
      assert event.resource_id == to_string(score.id)
      assert payload["score_id"] == score.id
      assert payload["type"] == "SUCCEEDED"
      assert payload["message"] == "Execution completed"
    end

    test "invalid params" do
      score = insert(:score, score_type: "ratio")
      insert(:score_event, type: "STARTED", score: score)

      params = %{
        "execution_timestamp" => nil,
        "result" => %{
          "invalid" => [[10]]
        }
      }

      assert {:error, :score, %{errors: errors}, %{}} =
               Scores.updated_succeeded_score(score, params)

      assert [
               execution_timestamp: {"can't be blank", [validation: :required]},
               score_content: {"can't be blank", [validation: :required]}
             ] = errors
    end
  end

  describe "updated_failed_score/2" do
    setup do
      IndexWorkerMock.clear()

      Redix.command!(["DEL", @audit_stream])

      on_exit(fn ->
        Redix.command!(["DEL", @audit_stream])
      end)

      :ok
    end

    test "updates score and set status as FAILED" do
      %{id: group_id} = group = insert(:score_group)

      %{quality_control_version: quality_control_version} =
        score = insert(:score, score_type: "ratio", group_id: group_id, group: group)

      quality_control_version_id = quality_control_version.id

      insert(:score_event, type: "STARTED", score: score)

      params = %{
        "execution_timestamp" => "2024-11-18 15:34:21.438113Z",
        "details" => %{"foo" => "bar"},
        "message" => "Execution completed"
      }

      assert {:ok,
              %{
                score: %{
                  execution_timestamp: ~U[2024-11-18 15:34:21.438113Z],
                  details: %{"foo" => "bar"}
                }
              }} = Scores.updated_failed_score(score, params)

      assert %{status: "FAILED"} = Scores.get_score(score.id, preload: :status)

      assert IndexWorkerMock.calls() == [
               {:reindex, :quality_control_versions, [ids: quality_control_version_id]}
             ]

      {:ok, events} = read_audit_events(@audit_stream, 2)
      assert length(events) == 2

      event = Enum.find(events, &(&1.event == "score_status_updated"))
      assert event.event == "score_status_updated"
      assert event.resource_type == "score"
      assert event.resource_id == to_string(score.id)
      payload = Jason.decode!(event.payload)
      assert payload["status"] == "failed"
      assert payload["latest_event_message"] == "Execution completed"
      assert payload["name"] == quality_control_version.name
      assert payload["control_mode"] == quality_control_version.control_mode

      assert payload["score_criteria"] == %{
               "deviation" => nil,
               "count" => nil,
               "error_count" => nil,
               "percentage" => %{
                 "goal" => 90.0,
                 "minimum" => 75.0
               }
             }

      event = Enum.find(events, &(&1.event == "score_event_created"))
      payload = Jason.decode!(event.payload)
      assert event.resource_type == "score"
      assert event.resource_id == to_string(score.id)
      assert payload["score_id"] == score.id
      assert payload["type"] == "FAILED"
      assert payload["message"] == "Execution completed"
    end

    test "invalid params" do
      score = insert(:score, score_type: "ratio")

      insert(:score_event, type: "STARTED", score: score)

      params =
        %{
          "execution_timestamp" => nil
        }

      assert {:error, :score, %{errors: errors}, %{}} = Scores.updated_failed_score(score, params)

      assert [
               execution_timestamp: {"can't be blank", [validation: :required]}
             ] = errors
    end
  end

  describe "delete_score/1" do
    setup do
      IndexWorkerMock.clear()

      Redix.command!(["DEL", @audit_stream])

      on_exit(fn ->
        Redix.command!(["DEL", @audit_stream])
      end)

      :ok
    end

    test "deletes a score and it score_group because is empty" do
      %{id: score_group_id} = score_group = insert(:score_group)
      score = insert(:score, group_id: score_group_id, group: score_group)

      assert !is_nil(Scores.get_score(score.id))
      assert !is_nil(Scores.get_score_group(score_group_id))

      assert {:ok, %Score{}} = Scores.delete_score(score)

      assert is_nil(Scores.get_score(score.id))
      assert is_nil(Scores.get_score_group(score_group_id))

      assert IndexWorkerMock.calls() == [
               {:delete, :score_groups, [score_group_id]},
               {:reindex, :quality_control_versions, [ids: score.quality_control_version_id]}
             ]

      {:ok, events} = read_audit_events(@audit_stream, 2)
      assert length(events) == 2

      event = Enum.find(events, &(&1.event == "score_deleted"))
      assert event.event == "score_deleted"
      assert event.resource_type == "score"
      assert event.resource_id == to_string(score.id)

      event = Enum.find(events, &(&1.event == "score_group_deleted"))
      assert event.event == "score_group_deleted"
      assert event.resource_type == "score_group"
      assert event.resource_id == to_string(score_group_id)
    end

    test "deletes a score of a group with more scores and the group is not deleted" do
      %{id: score_group_id} = score_group = insert(:score_group)
      score1 = insert(:score, group_id: score_group_id, group: score_group)
      score2 = insert(:score, group_id: score_group_id, group: score_group)

      assert !is_nil(Scores.get_score(score1.id))
      assert !is_nil(Scores.get_score(score2.id))
      assert !is_nil(Scores.get_score_group(score_group_id))

      assert {:ok, %Score{}} = Scores.delete_score(score1)

      assert is_nil(Scores.get_score(score1.id))
      assert !is_nil(Scores.get_score(score2.id))
      assert !is_nil(Scores.get_score_group(score_group_id))

      assert IndexWorkerMock.calls() == [
               {:reindex, :score_groups, [{:id, score_group_id}]},
               {:reindex, :quality_control_versions, [ids: score1.quality_control_version_id]}
             ]

      {:ok, events} = read_audit_events(@audit_stream, 2)
      assert length(events) == 1

      event = Enum.find(events, &(&1.event == "score_deleted"))
      assert event.event == "score_deleted"
      assert event.resource_type == "score"
      assert event.resource_id == to_string(score1.id)

      refute Enum.find(events, &(&1.event == "score_group_deleted"))
    end

    test "deletes score's events" do
      %{id: group_id} = group = insert(:score_group)
      score = insert(:score, group_id: group_id, group: group)

      insert(:score_event, type: "PENDING", score: score)

      assert [%TdQx.Scores.ScoreEvent{}] = Repo.all(ScoreEvent)

      assert {:ok, %Score{}} = Scores.delete_score(score)

      assert [] == Repo.all(ScoreEvent)
    end
  end

  describe "insert_event_for_scores/2" do
    setup do
      IndexWorkerMock.clear()

      Redix.command!(["DEL", @audit_stream])

      on_exit(fn ->
        Redix.command!(["DEL", @audit_stream])
      end)

      :ok
    end

    test "inserts events for all scores" do
      scores =
        for _ <- 1..3 do
          score = insert(:score)
          insert(:score_event, type: "PENDING", score: score)
          score
        end

      Scores.insert_event_for_scores(scores, %{type: "QUEUED"})

      assert scores = Scores.list_scores(preload: :status)
      assert Enum.all?(scores, &(&1.status == "QUEUED"))

      assert [{:reindex, :quality_control_versions, [ids: ids]}] = IndexWorkerMock.calls()
      assert Enum.sort(ids) == scores |> Enum.map(& &1.quality_control_version_id) |> Enum.sort()

      {:ok, events} = read_audit_events(@audit_stream, 3)
      assert length(events) == 3

      events = Enum.filter(events, &(&1.event == "score_event_created"))
      assert length(events) == 3

      for event <- events do
        assert event.resource_type == "score"
        assert event.resource_id in Enum.map(scores, &to_string(&1.id))
        payload = Jason.decode!(event.payload)
        assert payload["type"] == "QUEUED"
      end
    end
  end

  describe "create_score_event/1" do
    setup do
      IndexWorkerMock.clear()

      Redix.command!(["DEL", @audit_stream])

      on_exit(fn ->
        Redix.command!(["DEL", @audit_stream])
      end)

      :ok
    end

    test "creates a score_event" do
      %{id: score_id, quality_control_version_id: quality_control_version_id} = insert(:score)

      ttl = DateTime.utc_now()

      params = %{
        score_id: score_id,
        type: "PENDING",
        ttl: ttl,
        message: "some message"
      }

      assert {:ok, %{score_event: score_event}} = Scores.create_score_event(params)

      assert %{
               score_id: ^score_id,
               type: "PENDING",
               ttl: ^ttl,
               message: "some message"
             } = score_event

      assert IndexWorkerMock.calls() == [
               {:reindex, :quality_control_versions, [ids: quality_control_version_id]}
             ]

      {:ok, events} = read_audit_events(@audit_stream, 1)
      assert length(events) == 1

      event = Enum.find(events, &(&1.event == "score_event_created"))
      assert event.event == "score_event_created"
      assert event.resource_type == "score"
      assert event.resource_id == to_string(score_id)
      payload = Jason.decode!(event.payload)
      assert payload["score_id"] == score_id
      assert payload["type"] == "PENDING"
      assert payload["ttl"] == DateTime.to_iso8601(ttl)
      assert payload["message"] == "some message"
    end

    test "renders error for invalid params" do
      params = %{
        score_id: nil,
        type: nil,
        ttl: nil,
        message: nil
      }

      assert {:error, :score_event,
              %{
                errors: [
                  type: {"can't be blank", [validation: :required]},
                  score_id: {"can't be blank", [validation: :required]}
                ]
              }, %{}} = Scores.create_score_event(params)

      assert {:ok, []} == read_audit_events(@audit_stream, 1)
    end

    test "validate type" do
      %{id: score_id} = insert(:score)

      params = %{
        score_id: score_id,
        type: "invalid_type"
      }

      assert {:error, :score_event,
              %{
                errors: [
                  type:
                    {"is invalid",
                     [
                       validation: :inclusion,
                       enum: [
                         "QUEUED",
                         "TIMEOUT",
                         "PENDING",
                         "STARTED",
                         "INFO",
                         "WARNING",
                         "FAILED",
                         "SUCCEEDED"
                       ]
                     ]}
                ]
              }, %{}} = Scores.create_score_event(params)

      assert {:ok, []} == read_audit_events(@audit_stream, 1)
    end

    test "validate score foreign key" do
      params = %{
        score_id: 888,
        type: "TIMEOUT"
      }

      assert {:error, :score_event,
              %{
                errors: [
                  score_id:
                    {"does not exist",
                     [constraint: :foreign, constraint_name: "score_events_score_id_fkey"]}
                ]
              }, %{}} = Scores.create_score_event(params)

      assert {:ok, []} == read_audit_events(@audit_stream, 1)
    end
  end
end
