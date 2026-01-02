defmodule TdQx.Scores.AuditTest do
  use TdQx.DataCase

  alias TdCache.Redix
  alias TdQx.Scores.Audit, as: ScoreAudit
  alias TdQx.Scores.Score

  @audit_stream TdCache.Audit.stream()

  setup do
    # Clean up audit stream before each test
    Redix.command!(["DEL", @audit_stream])

    on_exit(fn ->
      Redix.command!(["DEL", @audit_stream])
    end)

    :ok
  end

  defp read_audit_events(stream \\ @audit_stream, count \\ 1) do
    TdCache.Redix.Stream.read(:redix, stream, count: count, transform: true)
  end

  describe "publish/3" do
    test "publishes audit event for ScoreGroup" do
      score_group = insert(:score_group, df_type: "test_type", created_by: 123)

      assert {:ok, _id} = ScoreAudit.publish(:score_group_created, score_group, 123)

      {:ok, events} = read_audit_events()
      assert length(events) == 1

      [event] = events
      assert event.event == "score_group_created"
      assert event.resource_type == "score_group"
      assert event.resource_id == to_string(score_group.id)
      assert event.user_id == "123"

      payload = Jason.decode!(event.payload)
      assert payload["df_type"] == "test_type"
      assert payload["created_by"] == 123
      assert payload["dynamic_content"] == %{}
    end

    test "publishes audit event for Score" do
      %{id: domain_id_1} = CacheHelpers.insert_domain(%{id: 1, parent_id: nil})
      %{id: domain_id_2} = CacheHelpers.insert_domain(%{id: 2, parent_id: domain_id_1})

      quality_control =
        insert(:quality_control, domain_ids: [domain_id_1, domain_id_2], source_id: 10)

      version =
        insert(:quality_control_version,
          quality_control: quality_control,
          name: "Test Control",
          version: 1
        )

      score_group = insert(:score_group)

      score =
        insert(:score,
          quality_control_version: version,
          group: score_group,
          score_type: "ratio",
          quality_control_status: "published",
          execution_timestamp: ~U[2024-01-01 12:00:00.000000Z],
          details: %{"key" => "value"},
          score_content:
            build(:score_content,
              ratio: build(:score_content_ratio)
            )
        )

      score = Repo.get!(Score, score.id)
      assert {:ok, _id} = ScoreAudit.publish(:score_created, score, 123)

      {:ok, events} = read_audit_events()
      assert length(events) == 1

      [event] = events
      assert event.event == "score_created"
      assert event.resource_type == "score"
      assert event.resource_id == to_string(score.id)
      assert event.user_id == "123"

      payload = Jason.decode!(event.payload)
      assert payload["score_type"] == "ratio"
      assert payload["quality_control_status"] == "published"
      assert payload["group_id"] == score_group.id
      assert payload["quality_control_version_id"] == version.id
      assert payload["quality_control_id"] == quality_control.id
      assert payload["details"] == %{"key" => "value"}
      assert payload["domain_ids"] == [domain_id_1, domain_id_2]
      assert payload["current_domains_ids"] == %{"1" => [1], "2" => [2, 1]}

      assert payload["score_content"] == %{
               "count" => nil,
               "ratio" => %{"total_count" => 10, "validation_count" => 1}
             }

      assert payload["result"] == %{
               "ratio_content" => %{"total_count" => 10, "validation_count" => 1},
               "result" => 10.0,
               "result_message" => "under_threshold"
             }
    end

    test "publishes audit event for ScoreEvent" do
      %{id: domain_id_1} = CacheHelpers.insert_domain(%{id: 1, parent_id: nil})
      %{id: domain_id_2} = CacheHelpers.insert_domain(%{id: 2, parent_id: domain_id_1})

      quality_control =
        insert(:quality_control, domain_ids: [domain_id_1, domain_id_2])

      version = insert(:quality_control_version, quality_control: quality_control)
      score = insert(:score, quality_control_version: version)

      score_event =
        insert(:score_event,
          score: score,
          type: "SUCCEEDED",
          message: "Execution completed"
        )

      assert {:ok, _id} = ScoreAudit.publish(:score_event_created, score_event, 123)

      {:ok, events} = read_audit_events()
      assert length(events) == 1

      [event] = events
      assert event.event == "score_event_created"
      assert event.resource_type == "score"
      assert event.resource_id == to_string(score.id)
      assert event.user_id == "123"

      payload = Jason.decode!(event.payload)
      assert payload["score_id"] == score.id
      assert payload["type"] == "SUCCEEDED"
      assert payload["message"] == "Execution completed"
      assert payload["domain_ids"] == [domain_id_1, domain_id_2]
    end

    test "enriches Score payload with quality_control_id" do
      quality_control = insert(:quality_control, source_id: 10)

      version =
        insert(:quality_control_version,
          quality_control: quality_control,
          name: "Test Control"
        )

      score = insert(:score, quality_control_version: version)

      assert {:ok, _id} = ScoreAudit.publish(:score_created, score, 123)

      assert {:ok, [event]} = read_audit_events()
      payload = Jason.decode!(event.payload)
      assert event.user_id == "123"
      assert payload["quality_control_version_id"] == version.id
      assert payload["quality_control_id"] == quality_control.id
    end
  end

  describe "publish_all/1" do
    test "publishes multiple audit events in batch" do
      score_group = insert(:score_group, created_by: 100)

      quality_control = insert(:quality_control)
      version = insert(:quality_control_version, quality_control: quality_control)

      score1 = insert(:score, quality_control_version: version, group: score_group)
      score2 = insert(:score, quality_control_version: version, group: score_group)

      events = [
        {:score_group_created, score_group},
        {:score_created, score1},
        {:score_created, score2}
      ]

      assert {:ok, events} = ScoreAudit.publish_all(events, 123)
      assert length(events) == 3

      {:ok, events_list} = read_audit_events(@audit_stream, 3)
      assert length(events_list) == 3

      [event1, event2, event3] = events_list

      assert event1.user_id == "123"
      assert event1.event == "score_group_created"
      assert event1.resource_type == "score_group"
      assert event1.resource_id == to_string(score_group.id)

      assert event2.user_id == "123"
      assert event2.event == "score_created"
      assert event2.resource_type == "score"
      assert event2.resource_id == to_string(score1.id)

      assert event3.user_id == "123"
      assert event3.event == "score_created"
      assert event3.resource_type == "score"
      assert event3.resource_id == to_string(score2.id)
    end

    test "handles mixed ScoreGroup, Score, and ScoreEvent entities" do
      score_group = insert(:score_group)
      quality_control = insert(:quality_control)
      version = insert(:quality_control_version, quality_control: quality_control)
      score = insert(:score, quality_control_version: version, group: score_group)
      score_event = insert(:score_event, score: score, type: "FAILED")

      events = [
        {:score_group_created, score_group},
        {:score_created, score},
        {:score_event_created, score_event}
      ]

      assert {:ok, events} = ScoreAudit.publish_all(events, 123)

      assert length(events) == 3
      {:ok, events_list} = read_audit_events(@audit_stream, 3)
      assert length(events_list) == 3

      # Verify resource types are correct
      [group_event, score_event_result, event_event] = events_list

      assert group_event.user_id == "123"
      assert group_event.resource_type == "score_group"
      assert score_event_result.user_id == "123"
      assert score_event_result.resource_type == "score"
      assert event_event.user_id == "123"
      assert event_event.resource_type == "score"
      assert event_event.resource_id == to_string(score.id)
    end

    test "includes all required fields in ScoreGroup payload" do
      score_group =
        insert(:score_group,
          df_type: "execution_type",
          dynamic_content: %{"param" => "value"},
          created_by: 456
        )

      assert {:ok, _id} = ScoreAudit.publish(:score_group_created, score_group, 123)

      {:ok, events} = read_audit_events()
      [event] = events
      payload = Jason.decode!(event.payload)

      assert event.user_id == "123"
      assert payload["id"] == score_group.id
      assert payload["df_type"] == "execution_type"
      assert payload["dynamic_content"] == %{"param" => "value"}
      assert payload["created_by"] == 456
    end

    test "includes all required fields in Score payload" do
      quality_control = insert(:quality_control)
      version = insert(:quality_control_version, quality_control: quality_control)
      score_group = insert(:score_group)

      execution_timestamp = ~U[2024-01-15 10:30:00.000000Z]

      score =
        insert(:score,
          quality_control_version: version,
          group: score_group,
          score_type: "count",
          quality_control_status: "draft",
          execution_timestamp: execution_timestamp,
          details: %{"execution_id" => "123", "duration" => 500}
        )

      assert {:ok, _id} = ScoreAudit.publish(:score_created, score, 123)

      {:ok, [event]} = read_audit_events()
      payload = Jason.decode!(event.payload)

      assert event.user_id == "123"
      assert payload["score_type"] == "count"
      assert payload["quality_control_status"] == "draft"
      assert payload["group_id"] == score_group.id
      assert payload["quality_control_version_id"] == version.id
      assert payload["quality_control_id"] == quality_control.id
      assert payload["details"] == %{"execution_id" => "123", "duration" => 500}
      assert payload["execution_timestamp"] == DateTime.to_iso8601(execution_timestamp)
    end

    test "includes all required fields in ScoreEvent payload" do
      quality_control = insert(:quality_control)
      version = insert(:quality_control_version, quality_control: quality_control)
      score = insert(:score, quality_control_version: version)

      ttl = ~U[2024-12-31 23:59:59.000000Z]

      score_event =
        insert(:score_event,
          score: score,
          type: "WARNING",
          message: "Performance warning",
          ttl: ttl
        )

      assert {:ok, _id} = ScoreAudit.publish(:score_event_created, score_event, 123)

      {:ok, events} = read_audit_events()
      [event] = events
      payload = Jason.decode!(event.payload)

      assert event.user_id == "123"
      assert payload["score_id"] == score.id
      assert payload["type"] == "WARNING"
      assert payload["message"] == "Performance warning"
      assert payload["ttl"] == DateTime.to_iso8601(ttl)
    end
  end
end
