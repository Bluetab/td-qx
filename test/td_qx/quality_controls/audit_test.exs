defmodule TdQx.QualityControls.AuditTest do
  use TdQx.DataCase

  import CacheHelpers
  import TdQx.TestOperators

  alias TdCache.Redix
  alias TdQx.QualityControls.Audit, as: QualityControlAudit

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

  describe "publish/2" do
    test "publishes audit event for QualityControl" do
      CacheHelpers.insert_domain(%{id: 1, parent_id: nil})
      CacheHelpers.insert_domain(%{id: 2, parent_id: 1})

      quality_control = insert(:quality_control, domain_ids: [1, 2], source_id: 10)

      assert {:ok, _id} =
               QualityControlAudit.publish(:quality_control_created, quality_control, 123)

      {:ok, events} = read_audit_events()
      assert length(events) == 1

      [event] = events
      assert event.event == "quality_control_created"
      assert event.resource_type == "quality_control"
      assert event.resource_id == to_string(quality_control.id)
      assert event.user_id == "123"
      payload = Jason.decode!(event.payload)
      assert payload["quality_control_id"] == quality_control.id
      assert payload["id"] == quality_control.id
      assert payload["source_id"] == 10
      assert payload["domain_ids"] == [1, 2]
      assert payload["active"] == true
      assert payload["current_domains_ids"] == %{"1" => [1], "2" => [2, 1]}
    end

    test "reduces payload to changes when metadata includes changes" do
      quality_control = insert(:quality_control, domain_ids: [1])

      metadata = %{changes: %{active: false}}

      assert {:ok, _id} =
               QualityControlAudit.publish(
                 :quality_control_updated,
                 quality_control,
                 321,
                 metadata
               )

      {:ok, [event]} = read_audit_events()

      assert event.event == "quality_control_updated"
      assert event.user_id == "321"

      payload = Jason.decode!(event.payload)
      assert payload["quality_control_id"] == quality_control.id
      assert payload["changes"]["active"] == false
    end

    test "publishes audit event for QualityControlVersion with preloaded quality_control" do
      quality_control = insert(:quality_control, domain_ids: [1, 2], source_id: 10)

      version =
        insert(:quality_control_version,
          quality_control: quality_control,
          name: "Test Control",
          version: 1,
          status: "draft"
        )

      version = Repo.preload(version, :quality_control)

      assert {:ok, _id} = QualityControlAudit.publish(:quality_control_created, version, 123)

      {:ok, events} = read_audit_events()
      assert length(events) == 1

      [event] = events
      assert event.event == "quality_control_created"
      assert event.resource_type == "quality_control"
      assert event.resource_id == to_string(quality_control.id)
      assert event.user_id == "123"
      payload = Jason.decode!(event.payload)
      assert payload["quality_control_id"] == quality_control.id
      assert payload["source_id"] == 10
      assert payload["name"] == "Test Control"
      assert payload["version"] == 1
      assert payload["status"] == "draft"
    end

    test "enriches domain_ids with hierarchical domains from cache" do
      _parent_domain = insert_domain(%{id: 1, parent_id: nil})
      _child_domain = insert_domain(%{id: 2, parent_id: 1})

      quality_control = insert(:quality_control, domain_ids: [2])

      assert {:ok, _id} =
               QualityControlAudit.publish(:quality_control_created, quality_control, 123)

      {:ok, events} = read_audit_events()
      assert length(events) == 1

      [event] = events
      payload = Jason.decode!(event.payload)
      assert event.user_id == "123"
      assert payload["domain_id"] == 2
      assert 2 in payload["domain_ids"]
      # Parent domain should be included
      assert 1 in payload["domain_ids"]
    end

    test "enriches names from domains in payload adding news and old names" do
      current_domain_1 = CacheHelpers.insert_domain(%{name: "Old domain 1"})
      current_domain_2 = CacheHelpers.insert_domain(%{name: "Old domain 2"})

      new_domain_1 = CacheHelpers.insert_domain(%{name: "New Domain 1"})
      new_domain_2 = CacheHelpers.insert_domain(%{name: "New Domain 2"})

      quality_control =
        insert(:quality_control,
          domain_ids: [current_domain_1.id, current_domain_2.id]
        )

      assert {:ok, _id} =
               QualityControlAudit.publish(:quality_control_updated, quality_control, 123, %{
                 changes: %{domain_ids: [new_domain_1.id, new_domain_2.id]},
                 current_domains: [current_domain_1.id, current_domain_2.id]
               })

      {:ok, [event]} = read_audit_events()

      payload = Jason.decode!(event.payload)

      new_domains = get_in(payload, ["changes", "domains"])

      current_domains = payload["current_domains"]

      assert new_domains |||
               [
                 %{"id" => new_domain_1.id},
                 %{"id" => new_domain_2.id}
               ]

      assert current_domains |||
               [
                 %{"id" => current_domain_1.id},
                 %{"id" => current_domain_2.id}
               ]
    end

    test "handles missing domain in cache gracefully" do
      CacheHelpers.insert_domain(%{id: 999, parent_id: nil})
      quality_control = insert(:quality_control, domain_ids: [999])

      assert {:ok, _id} =
               QualityControlAudit.publish(:quality_control_created, quality_control, 123)

      {:ok, events} = read_audit_events()
      assert length(events) == 1

      [event] = events
      payload = Jason.decode!(event.payload)
      assert event.user_id == "123"
      assert payload["domain_id"] == 999
      assert payload["domain_ids"] == [999]
    end

    test "handles empty domain_ids" do
      quality_control = insert(:quality_control, domain_ids: [])

      assert {:ok, _id} =
               QualityControlAudit.publish(:quality_control_created, quality_control, 123)

      {:ok, events} = read_audit_events()
      assert length(events) == 1

      [event] = events
      payload = Jason.decode!(event.payload)
      assert event.user_id == "123"
      assert payload["domain_ids"] == []
      refute payload["domain_id"]
    end
  end

  describe "publish_all/1" do
    test "publishes multiple audit events in batch" do
      qc1 = insert(:quality_control, domain_ids: [1], source_id: 10)
      qc2 = insert(:quality_control, domain_ids: [2], source_id: 20)

      version =
        insert(:quality_control_version,
          quality_control: qc1,
          name: "Version Control",
          version: 1
        )

      version = Repo.preload(version, :quality_control)

      events = [
        {:quality_control_created, qc1},
        {:quality_control_updated, qc2},
        {:quality_control_status_updated, version}
      ]

      assert {:ok, events} = QualityControlAudit.publish_all(events, 123)
      assert length(events) == 3

      {:ok, events_list} = read_audit_events(@audit_stream, 3)
      assert length(events_list) == 3

      [event1, event2, event3] = events_list

      assert event1.event == "quality_control_created"
      assert event1.resource_id == to_string(qc1.id)
      assert event1.resource_type == "quality_control"
      assert event1.user_id == "123"
      assert event2.event == "quality_control_updated"
      assert event2.resource_id == to_string(qc2.id)
      assert event2.user_id == "123"
      assert event3.event == "quality_control_status_updated"
      assert event3.resource_id == to_string(qc1.id)
      assert event3.user_id == "123"
      assert Jason.decode!(event3.payload)["name"] == "Version Control"
    end

    test "handles mixed QualityControl and QualityControlVersion entities" do
      qc = insert(:quality_control, domain_ids: [1])
      version = insert(:quality_control_version, quality_control: qc)
      version = Repo.preload(version, :quality_control)

      events = [
        {:quality_control_created, qc},
        {:quality_control_version_created, version}
      ]

      assert {:ok, events} = QualityControlAudit.publish_all(events, 123)

      assert length(events) == 2
      {:ok, events_list} = read_audit_events(@audit_stream, 2)
      assert length(events_list) == 2
    end

    test "allows event-specific metadata for changes" do
      qc = insert(:quality_control, domain_ids: [1])

      events = [
        {:quality_control_updated, qc, %{changes: %{active: false}}}
      ]

      assert {:ok, [_event]} = QualityControlAudit.publish_all(events, 123, %{action: "update"})

      {:ok, [event]} = read_audit_events()
      payload = Jason.decode!(event.payload)
      assert payload["quality_control_id"] == qc.id
      assert payload["changes"]["active"] == false
      assert payload["action"] == "update"
    end
  end
end
