defmodule TdQx.QualityControlWorkflowTest do
  use TdQx.DataCase

  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdCluster.TestHelpers.TdDfMock
  alias TdCore.Search.IndexWorkerMock
  alias TdQx.QualityControls
  alias TdQx.QualityControls.QualityControl
  alias TdQx.QualityControls.QualityControlVersion
  alias TdQx.QualityControlWorkflow

  @audit_stream TdCache.Audit.stream()

  setup do
    Redix.command!(["DEL", @audit_stream])

    on_exit(fn ->
      Redix.command!(["DEL", @audit_stream])
    end)

    :ok
  end

  describe "create_quality_control/1" do
    test "creates quality control and its version" do
      CacheHelpers.insert_domain(%{id: 1, parent_id: nil})
      CacheHelpers.insert_domain(%{id: 2, parent_id: 1})

      params = %{
        "domain_ids" => [1, 2],
        "name" => "some name",
        "control_mode" => "percentage",
        "source_id" => 10
      }

      assert {:ok,
              %QualityControlVersion{
                name: "some name",
                control_mode: "percentage",
                quality_control: %QualityControl{domain_ids: [1, 2]} = quality_control
              }} = QualityControlWorkflow.create_quality_control(params)

      assert {:ok, [event]} = Stream.read(:redix, @audit_stream, count: 1, transform: true)

      assert event.event == "quality_control_created"
      assert event.resource_type == "quality_control"
      assert event.resource_id == to_string(quality_control.id)

      payload = Jason.decode!(event.payload)
      assert payload["quality_control_id"] == quality_control.id
      assert payload["name"] == "some name"
      assert payload["control_mode"] == "percentage"
      assert payload["domain_ids"] == [1, 2]
      assert payload["source_id"] == 10
      assert payload["df_type"] == nil
      assert payload["dynamic_content"] == nil
    end

    test "validates quality control unique name and status" do
      %{name: name} =
        insert(:quality_control_version,
          quality_control: insert(:quality_control)
        )

      assert {:error, %{errors: errors}} =
               QualityControlWorkflow.create_quality_control(%{
                 name: name,
                 control_mode: "percentage",
                 domain_ids: [1, 2],
                 source_id: 10
               })

      assert [name: {"duplicated_name", []}] = errors
    end

    test "validates quality control unique name" do
      %{name: name} =
        insert(:quality_control_version,
          status: "published",
          quality_control: insert(:quality_control)
        )

      assert {:error, %{errors: errors}} =
               QualityControlWorkflow.create_quality_control(%{
                 name: name,
                 control_mode: "percentage",
                 domain_ids: [1, 2],
                 source_id: 10
               })

      assert [name: {"duplicated_name", []}] = errors
    end

    test "validates quality control required fields" do
      assert {:error, %{errors: errors}} = QualityControlWorkflow.create_quality_control(%{})

      assert [
               {:domain_ids, {"can't be blank", [validation: :required]}},
               {:source_id, {"can't be blank", [validation: :required]}}
             ] = errors

      assert {:error, %{errors: errors}} =
               QualityControlWorkflow.create_quality_control(%{domain_ids: [1, 2], source_id: 10})

      assert [
               name: {"can't be blank", [validation: :required]},
               control_mode: {"can't be blank", [validation: :required]}
             ] = errors
    end

    test "calls reindex after creation" do
      params = %{
        "domain_ids" => [1, 2],
        "source_id" => 10,
        "name" => "some name",
        "control_mode" => "percentage"
      }

      IndexWorkerMock.clear()

      assert {:ok,
              %QualityControlVersion{
                quality_control_id: id,
                name: "some name",
                control_mode: "percentage",
                quality_control: %QualityControl{
                  domain_ids: [1, 2],
                  source_id: 10
                }
              }} = QualityControlWorkflow.create_quality_control(params)

      assert IndexWorkerMock.calls() == [
               {:reindex, :quality_control_versions, [{:quality_control_ids, [id]}]}
             ]
    end
  end

  describe "create_quality_control_draft/2" do
    test "creates draft version from published version" do
      quality_control = insert(:quality_control, domain_ids: [1, 2], source_id: 10)

      published_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          name: "Published Control",
          version: 1,
          status: "published"
        )

      quality_control = QualityControls.get_quality_control!(quality_control.id)

      params = %{
        "name" => "New Draft Control",
        "status" => "draft",
        "control_mode" => "percentage",
        "df_type" => "some_type",
        "dynamic_content" => %{},
        "score_criteria" => string_params_for(:sc_percentage),
        "control_properties" => string_params_for(:cp_ratio_params_for)
      }

      assert {:ok,
              %QualityControlVersion{
                name: "New Draft Control",
                version: 2,
                status: "draft",
                control_mode: "percentage",
                quality_control: %QualityControl{domain_ids: [1, 2]} = quality_control
              } = new_version} =
               QualityControlWorkflow.create_quality_control_draft(quality_control, params)

      # Verify published version is unchanged
      updated_published = Repo.get!(QualityControlVersion, published_version.id)
      assert updated_published.status == "published"
      assert updated_published.version == 1

      # Verify audit event
      assert {:ok, [event]} = Stream.read(:redix, @audit_stream, count: 1, transform: true)
      assert event.event == "quality_control_version_draft_created"
      assert event.resource_type == "quality_control"
      assert event.resource_id == to_string(quality_control.id)

      payload = Jason.decode!(event.payload)
      assert payload["quality_control_version_id"] == new_version.id
      assert payload["quality_control_id"] == quality_control.id
      assert payload["name"] == "New Draft Control"
      assert payload["version"] == 2
      assert payload["status"] == "draft"
    end

    test "creates draft that gets published directly and versions old published version" do
      quality_control = insert(:quality_control, domain_ids: [1], source_id: 10)

      published_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          name: "Published Control",
          version: 1,
          status: "published"
        )

      quality_control = QualityControls.get_quality_control!(quality_control.id)

      template_name = "df_type"

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: [%{"name" => "group", "fields" => [%{"name" => "foo"}]}]}}
      )

      params = %{
        "name" => "New Published Control",
        "status" => "published",
        "control_mode" => "percentage",
        "df_type" => template_name,
        "dynamic_content" => %{"foo" => %{"value" => "bar", "origin" => "user"}},
        "score_criteria" => string_params_for(:sc_percentage),
        "control_properties" => string_params_for(:cp_ratio_params_for)
      }

      assert {:ok,
              %QualityControlVersion{
                name: "New Published Control",
                version: 2,
                status: "published"
              } = new_version} =
               QualityControlWorkflow.create_quality_control_draft(quality_control, params)

      # Verify the old published version was versioned
      updated_published = Repo.get!(QualityControlVersion, published_version.id)
      assert updated_published.status == "versioned"
      assert updated_published.version == 1

      assert {:ok, [event]} = Stream.read(:redix, @audit_stream, count: 1, transform: true)
      assert event.event == "quality_control_version_draft_created"
      assert event.resource_type == "quality_control"
      assert event.resource_id == to_string(quality_control.id)
      payload = Jason.decode!(event.payload)
      assert payload["quality_control_id"] == quality_control.id
      assert payload["df_type"] == template_name
      assert payload["dynamic_content"] == %{"foo" => %{"value" => "bar", "origin" => "user"}}
      assert payload["quality_control_version_id"] == new_version.id
      assert payload["version"] == 2
      assert payload["status"] == "published"
    end

    test "returns error when quality control has no published version" do
      quality_control = insert(:quality_control)

      quality_control = QualityControls.get_quality_control!(quality_control.id)

      params = %{
        "name" => "New Draft",
        "status" => "draft",
        "control_mode" => "percentage"
      }

      assert {:error, :invalid_action, "create_draft not published"} =
               QualityControlWorkflow.create_quality_control_draft(quality_control, params)

      # Verify no audit event was published
      assert {:ok, []} = Stream.read(:redix, @audit_stream, count: 1, transform: true)
    end

    test "returns error when quality control has draft version but no published version" do
      quality_control = insert(:quality_control)

      _draft_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "draft",
          version: 1
        )

      quality_control = QualityControls.get_quality_control!(quality_control.id)

      params = %{
        "name" => "New Draft",
        "status" => "draft",
        "control_mode" => "percentage"
      }

      assert {:error, :invalid_action, "create_draft not published"} =
               QualityControlWorkflow.create_quality_control_draft(quality_control, params)
    end

    test "validates required fields for draft version" do
      quality_control = insert(:quality_control)

      _published_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "published",
          version: 1
        )

      quality_control = QualityControls.get_quality_control!(quality_control.id)

      assert {:error, %{errors: errors}} =
               QualityControlWorkflow.create_quality_control_draft(quality_control, %{})

      assert [
               name: {"can't be blank", [validation: :required]},
               control_mode: {"can't be blank", [validation: :required]}
             ] = errors
    end

    test "validates unique name constraint" do
      quality_control = insert(:quality_control)

      _published_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          name: "Existing Name",
          status: "published",
          version: 1
        )

      insert(:quality_control_version,
        quality_control: build(:quality_control),
        name: "Existing Name",
        status: "draft",
        version: 1
      )

      quality_control = QualityControls.get_quality_control!(quality_control.id)

      params = %{
        "name" => "Existing Name",
        "status" => "draft",
        "control_mode" => "percentage"
      }

      assert {:error, %{errors: errors}} =
               QualityControlWorkflow.create_quality_control_draft(quality_control, params)

      assert [name: {"duplicated_name", []}] = errors
    end

    test "validates control_mode inclusion" do
      quality_control = insert(:quality_control)

      _published_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "published",
          version: 1
        )

      quality_control = QualityControls.get_quality_control!(quality_control.id)

      params = %{
        "name" => "New Draft",
        "status" => "draft",
        "control_mode" => "invalid_mode"
      }

      assert {:error, %{errors: errors}} =
               QualityControlWorkflow.create_quality_control_draft(quality_control, params)

      assert [
               control_mode:
                 {"is invalid",
                  [
                    validation: :inclusion,
                    enum: ["deviation", "percentage", "count", "error_count"]
                  ]}
             ] = errors
    end

    test "validates status inclusion for draft creation" do
      quality_control = insert(:quality_control)

      _published_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "published",
          version: 1
        )

      quality_control = QualityControls.get_quality_control!(quality_control.id)

      params = %{
        "name" => "New Draft",
        "status" => "invalid_status",
        "control_mode" => "percentage"
      }

      assert {:error, %{errors: errors}} =
               QualityControlWorkflow.create_quality_control_draft(quality_control, params)

      assert [
               status: {"is invalid", [validation: :inclusion, enum: ["draft", "published"]]}
             ] = errors
    end

    test "validates published status requires all fields" do
      quality_control = insert(:quality_control)

      _published_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "published",
          version: 1
        )

      quality_control = QualityControls.get_quality_control!(quality_control.id)

      params = %{
        "name" => "New Published",
        "status" => "published",
        "control_mode" => "percentage"
        ## REVIEW  TD-7675: A que se refiere con los campos que faltan?
        # Missing: df_type, dynamic_content, score_criteria, control_properties
      }

      assert {:error, %{errors: errors}} =
               QualityControlWorkflow.create_quality_control_draft(quality_control, params)

      assert errors[:df_type] == {"can't be blank", [validation: :required]}
      assert errors[:dynamic_content] == {"can't be blank", [validation: :required]}
      assert errors[:score_criteria] == {"can't be blank", [validation: :required]}
      assert errors[:control_properties] == {"can't be blank", [validation: :required]}
    end

    test "calls reindex after draft creation" do
      quality_control = insert(:quality_control)

      _published_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "published",
          version: 1
        )

      quality_control = QualityControls.get_quality_control!(quality_control.id)

      params = %{
        "name" => "New Draft",
        "status" => "draft",
        "control_mode" => "percentage",
        "df_type" => "some_type",
        "dynamic_content" => %{},
        "score_criteria" => string_params_for(:sc_percentage),
        "control_properties" => string_params_for(:cp_ratio_params_for)
      }

      IndexWorkerMock.clear()

      assert {:ok,
              %QualityControlVersion{
                quality_control_id: id,
                name: "New Draft"
              }} = QualityControlWorkflow.create_quality_control_draft(quality_control, params)

      assert IndexWorkerMock.calls() == [
               {:reindex, :quality_control_versions, [{:quality_control_ids, [id]}]}
             ]
    end

    test "increments version number correctly" do
      quality_control = insert(:quality_control)

      _published_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "published",
          version: 3
        )

      quality_control = QualityControls.get_quality_control!(quality_control.id)

      params = %{
        "name" => "New Draft",
        "status" => "draft",
        "control_mode" => "percentage",
        "df_type" => "some_type",
        "dynamic_content" => %{},
        "score_criteria" => string_params_for(:sc_percentage),
        "control_properties" => string_params_for(:cp_ratio_params_for)
      }

      assert {:ok, %QualityControlVersion{version: 4}} =
               QualityControlWorkflow.create_quality_control_draft(quality_control, params)
    end
  end

  describe "changesets_for_action/2" do
    test "cast changeset for latest version on action send_to_approval" do
      quality_control = insert(:quality_control)

      _published_version =
        insert(:quality_control_version,
          status: "published",
          version: 1,
          quality_control: quality_control
        )

      %{id: qcv_id} =
        _latest_version =
        insert(:quality_control_version,
          status: "draft",
          version: 2,
          quality_control: quality_control
        )

      quality_control =
        QualityControls.get_quality_control!(quality_control.id, preload: :published_version)

      assert {:ok,
              [
                {:update,
                 %Ecto.Changeset{
                   valid?: true,
                   data: %{
                     id: ^qcv_id
                   },
                   changes: %{
                     status: "pending_approval"
                   }
                 }}
              ]} =
               QualityControlWorkflow.changesets_for_action(quality_control, "send_to_approval")
    end

    test "cast changeset for latest version on action publish with versions" do
      quality_control = insert(:quality_control)

      %{id: published_qcv_id} =
        _published_version =
        insert(:quality_control_version,
          status: "published",
          version: 1,
          quality_control: quality_control
        )

      %{id: latest_qcv_id} =
        _latest_version =
        insert(:quality_control_version,
          status: "draft",
          version: 2,
          quality_control: quality_control
        )

      quality_control =
        QualityControls.get_quality_control!(quality_control.id, preload: :published_version)

      assert {:ok,
              [
                {:update,
                 %Ecto.Changeset{
                   valid?: true,
                   data: %{
                     id: ^published_qcv_id
                   },
                   changes: %{
                     status: "versioned"
                   }
                 }},
                {:update,
                 %Ecto.Changeset{
                   valid?: true,
                   data: %{
                     id: ^latest_qcv_id
                   },
                   changes: %{
                     status: "published"
                   }
                 }}
              ]} = QualityControlWorkflow.changesets_for_action(quality_control, "publish")
    end

    test "cast changeset for latest version on action publish without versions" do
      quality_control = insert(:quality_control)

      %{id: latest_qcv_id} =
        _latest_version =
        insert(:quality_control_version,
          status: "draft",
          version: 1,
          quality_control: quality_control
        )

      quality_control =
        QualityControls.get_quality_control!(quality_control.id, preload: :published_version)

      assert {:ok,
              [
                {:update,
                 %Ecto.Changeset{
                   valid?: true,
                   data: %{
                     id: ^latest_qcv_id
                   },
                   changes: %{
                     status: "published"
                   }
                 }}
              ]} = QualityControlWorkflow.changesets_for_action(quality_control, "publish")
    end

    test "cast changeset for action deprecate without pending latest" do
      quality_control = insert(:quality_control)

      _versioned_version =
        insert(:quality_control_version,
          status: "versioned",
          version: 1,
          quality_control: quality_control
        )

      %{id: published_qcv_id} =
        _published_version =
        insert(:quality_control_version,
          status: "published",
          version: 2,
          quality_control: quality_control
        )

      quality_control =
        QualityControls.get_quality_control!(quality_control.id, preload: :published_version)

      assert {:ok,
              [
                {:update,
                 %Ecto.Changeset{
                   valid?: true,
                   data: %{
                     id: ^published_qcv_id
                   },
                   changes: %{
                     status: "deprecated"
                   }
                 }}
              ]} = QualityControlWorkflow.changesets_for_action(quality_control, "deprecate")
    end

    test "cast changeset for action deprecate with pending version" do
      quality_control = insert(:quality_control)

      _versioned_version =
        insert(:quality_control_version,
          status: "versioned",
          version: 1,
          quality_control: quality_control
        )

      %{id: published_qcv_id} =
        _published_version =
        insert(:quality_control_version,
          status: "published",
          version: 2,
          quality_control: quality_control
        )

      %{id: draft_qcv_id} =
        _latest_version =
        insert(:quality_control_version,
          status: "draft",
          version: 3,
          quality_control: quality_control
        )

      quality_control =
        QualityControls.get_quality_control!(quality_control.id, preload: :published_version)

      assert {:ok,
              [
                {:delete, %{id: ^draft_qcv_id}},
                {:update,
                 %Ecto.Changeset{
                   valid?: true,
                   data: %{
                     id: ^published_qcv_id
                   },
                   changes: %{
                     status: "deprecated"
                   }
                 }}
              ]} = QualityControlWorkflow.changesets_for_action(quality_control, "deprecate")
    end

    test "cast changeset for latest version on action reject" do
      quality_control = insert(:quality_control)

      _published_version =
        insert(:quality_control_version,
          status: "published",
          version: 1,
          quality_control: quality_control
        )

      %{id: qcv_id} =
        _latest_version =
        insert(:quality_control_version,
          status: "pending_approval",
          version: 2,
          quality_control: quality_control
        )

      quality_control =
        QualityControls.get_quality_control!(quality_control.id, preload: :published_version)

      assert {:ok,
              [
                {:update,
                 %Ecto.Changeset{
                   valid?: true,
                   data: %{
                     id: ^qcv_id
                   },
                   changes: %{
                     status: "rejected"
                   }
                 }}
              ]} = QualityControlWorkflow.changesets_for_action(quality_control, "reject")
    end

    test "cast changeset for unique version on action reject" do
      quality_control = insert(:quality_control)

      %{id: qcv_id} =
        _latest_version =
        insert(:quality_control_version,
          status: "pending_approval",
          version: 1,
          quality_control: quality_control
        )

      quality_control =
        QualityControls.get_quality_control!(quality_control.id, preload: :published_version)

      assert {:ok,
              [
                {:update,
                 %Ecto.Changeset{
                   valid?: true,
                   data: %{
                     id: ^qcv_id
                   },
                   changes: %{
                     status: "rejected"
                   }
                 }}
              ]} = QualityControlWorkflow.changesets_for_action(quality_control, "reject")
    end

    test "cast changeset for latest version on action send_to_draft" do
      quality_control = insert(:quality_control)

      _published_version =
        insert(:quality_control_version,
          status: "published",
          version: 1,
          quality_control: quality_control
        )

      %{id: qcv_id} =
        _latest_version =
        insert(:quality_control_version,
          status: "rejected",
          version: 2,
          quality_control: quality_control
        )

      quality_control =
        QualityControls.get_quality_control!(quality_control.id, preload: :published_version)

      assert {:ok,
              [
                {:update,
                 %Ecto.Changeset{
                   valid?: true,
                   data: %{
                     id: ^qcv_id
                   },
                   changes: %{
                     status: "draft"
                   }
                 }}
              ]} = QualityControlWorkflow.changesets_for_action(quality_control, "send_to_draft")
    end

    test "cast changeset for unique version on action send_to_draft" do
      quality_control = insert(:quality_control)

      %{id: qcv_id} =
        _latest_version =
        insert(:quality_control_version,
          status: "rejected",
          version: 1,
          quality_control: quality_control
        )

      quality_control =
        QualityControls.get_quality_control!(quality_control.id, preload: :published_version)

      assert {:ok,
              [
                {:update,
                 %Ecto.Changeset{
                   valid?: true,
                   data: %{
                     id: ^qcv_id
                   },
                   changes: %{
                     status: "draft"
                   }
                 }}
              ]} = QualityControlWorkflow.changesets_for_action(quality_control, "send_to_draft")
    end

    test "returns error for invalid action" do
      quality_control = insert(:quality_control)

      assert {:error, :invalid_action, "invalid_action"} =
               QualityControlWorkflow.changesets_for_action(quality_control, "invalid_action")
    end

    test "returns error for invalid quality control" do
      assert {:error, :invalid_quality_control} =
               QualityControlWorkflow.changesets_for_action(nil, "publish")
    end
  end

  describe "validate_publish_changeset/2" do
    for target_status <- ["published", "pending_approval"] do
      @tag [target_status: target_status]
      test "requires all version fields for #{target_status} target status", %{
        target_status: target_status
      } do
        quality_control_version =
          insert(:quality_control_version,
            dynamic_content: nil,
            df_type: nil,
            score_criteria: nil,
            control_mode: nil,
            control_properties: nil,
            quality_control: insert(:quality_control)
          )

        changeset = QualityControlVersion.status_changeset(quality_control_version, target_status)

        assert {:update, %{valid?: false, errors: errors}} =
                 QualityControlWorkflow.validate_publish_changeset(
                   {:update, changeset},
                   "publish"
                 )

        assert [
                 {:control_properties, {"can't be blank", [validation: :required]}},
                 {:score_criteria, {"can't be blank", [validation: :required]}},
                 {:dynamic_content, {"can't be blank", [validation: :required]}},
                 {:df_type, {"can't be blank", [validation: :required]}},
                 {:control_mode, {"can't be blank", [validation: :required]}}
               ] = errors
      end
    end

    test "handles invalid template not found" do
      template_name = "df_type"

      TdDfMock.get_template_by_name!(&Mox.expect/4, template_name, {:ok, nil})

      quality_control_version =
        insert(:quality_control_version,
          dynamic_content: %{"foo" => %{"value" => "bar", "origin" => "user"}},
          df_type: template_name,
          score_criteria: %{},
          control_mode: "percentage",
          control_properties: build(:control_properties),
          quality_control: insert(:quality_control)
        )

      changeset = QualityControlVersion.status_changeset(quality_control_version, "published")

      assert {:update, %{valid?: false, errors: errors}} =
               QualityControlWorkflow.validate_publish_changeset({:update, changeset}, "publish")

      assert [dynamic_content: {"invalid template", [reason: :template_not_found]}] == errors
    end

    test "handles invalid content for template" do
      template_name = "df_type"

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok,
         %{
           content: [
             %{"name" => "group", "fields" => [%{"name" => "foo", "cardinality" => "1"}]}
           ]
         }}
      )

      quality_control_version =
        insert(:quality_control_version,
          dynamic_content: %{"not_foo" => %{"value" => "bar", "origin" => "user"}},
          df_type: template_name,
          score_criteria: %{},
          control_mode: "percentage",
          control_properties: build(:control_properties),
          quality_control: insert(:quality_control)
        )

      changeset = QualityControlVersion.status_changeset(quality_control_version, "published")

      assert {:update, %{valid?: false, errors: errors}} =
               QualityControlWorkflow.validate_publish_changeset({:update, changeset}, "publish")

      assert [
               dynamic_content:
                 {"foo: can't be blank", [foo: {"can't be blank", [validation: :required]}]}
             ] == errors
    end

    for target_status <- ["published", "pending_approval"] do
      @tag [target_status: target_status]
      test "valid changeset for #{target_status} target status", %{
        target_status: target_status
      } do
        template_name = "df_type"

        TdDfMock.get_template_by_name!(
          &Mox.expect/4,
          template_name,
          {:ok, %{content: [%{"name" => "group", "fields" => [%{"name" => "foo"}]}]}}
        )

        quality_control_version =
          insert(:quality_control_version,
            dynamic_content: %{"foo" => %{"value" => "bar", "origin" => "user"}},
            df_type: template_name,
            score_criteria: %{},
            control_mode: "percentage",
            control_properties: build(:control_properties),
            quality_control: insert(:quality_control)
          )

        changeset = QualityControlVersion.status_changeset(quality_control_version, target_status)

        assert {:update, %{valid?: true, errors: errors}} =
                 QualityControlWorkflow.validate_publish_changeset(
                   {:update, changeset},
                   "publish"
                 )

        assert [] == errors
      end
    end

    for target_status <- ["draft", "rejected", "versioned", "deprecated"] do
      @tag [target_status: target_status]
      test "does not validate version fields for #{target_status} target status", %{
        target_status: target_status
      } do
        quality_control_version =
          insert(:quality_control_version,
            dynamic_content: nil,
            df_type: nil,
            score_criteria: nil,
            control_mode: nil,
            control_properties: nil,
            quality_control: insert(:quality_control)
          )

        changeset = QualityControlVersion.status_changeset(quality_control_version, target_status)

        assert {:update, %{valid?: true, errors: errors}} =
                 QualityControlWorkflow.validate_publish_changeset(
                   {:update, changeset},
                   "publish"
                 )

        assert [] == errors
      end
    end

    test "does not validate version fields for action restore" do
      quality_control_version =
        insert(:quality_control_version,
          dynamic_content: nil,
          df_type: nil,
          score_criteria: nil,
          control_mode: nil,
          control_properties: nil,
          quality_control: insert(:quality_control)
        )

      changeset = QualityControlVersion.status_changeset(quality_control_version, "published")

      assert {:update, %{valid?: true, errors: errors}} =
               QualityControlWorkflow.validate_publish_changeset(
                 {:update, changeset},
                 "restore"
               )

      assert [] == errors
    end
  end

  describe "update_quality_control_status/2" do
    test "publishes draft version without existing published version" do
      quality_control = insert(:quality_control)

      template_name = "df_type"

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: [%{"name" => "group", "fields" => [%{"name" => "foo"}]}]}}
      )

      draft_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "draft",
          version: 1,
          name: "Draft Control",
          df_type: template_name,
          dynamic_content: %{"foo" => %{"value" => "bar", "origin" => "user"}},
          control_mode: "percentage",
          score_criteria: string_params_for(:sc_percentage),
          control_properties: string_params_for(:cp_ratio_params_for)
        )

      quality_control =
        QualityControls.get_quality_control!(quality_control.id, preload: :published_version)

      IndexWorkerMock.clear()

      assert {:ok, %QualityControlVersion{status: "published"}} =
               QualityControlWorkflow.update_quality_control_status(quality_control, "publish")

      updated = Repo.get!(QualityControlVersion, draft_version.id)
      assert updated.status == "published"

      assert IndexWorkerMock.calls() == [
               {:reindex, :quality_control_versions,
                [{:quality_control_ids, [quality_control.id]}]}
             ]

      assert {:ok, [event]} = Stream.read(:redix, @audit_stream, count: 1, transform: true)
      assert event.event == "quality_control_version_status_updated"
      assert event.resource_type == "quality_control"
      assert event.resource_id == to_string(quality_control.id)
      payload = Jason.decode!(event.payload)
      assert payload["quality_control_version_id"] == draft_version.id
      assert payload["quality_control_id"] == quality_control.id
      assert payload["status"] == "published"
      assert payload["action"] == "publish"
    end

    test "publishes draft version and versions existing published version" do
      quality_control = insert(:quality_control)

      template_name = "df_type"

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: [%{"name" => "group", "fields" => [%{"name" => "foo"}]}]}}
      )

      published_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "published",
          version: 1
        )

      draft_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "draft",
          version: 2,
          name: "Draft Control",
          df_type: template_name,
          dynamic_content: %{"foo" => %{"value" => "bar", "origin" => "user"}},
          control_mode: "percentage",
          score_criteria: string_params_for(:sc_percentage),
          control_properties: string_params_for(:cp_ratio_params_for)
        )

      quality_control =
        QualityControls.get_quality_control!(quality_control.id, preload: :published_version)

      assert {:ok, %QualityControlVersion{status: "published"}} =
               QualityControlWorkflow.update_quality_control_status(quality_control, "publish")

      updated_published = Repo.get!(QualityControlVersion, published_version.id)
      assert updated_published.status == "versioned"

      updated_draft = Repo.get!(QualityControlVersion, draft_version.id)
      assert updated_draft.status == "published"

      assert {:ok, [published_event, versioned_event]} =
               Stream.read(:redix, @audit_stream, count: 2, transform: true)

      assert published_event.event == "quality_control_version_status_updated"
      assert published_event.resource_type == "quality_control"
      assert published_event.resource_id == to_string(quality_control.id)
      payload = Jason.decode!(published_event.payload)
      assert payload["quality_control_version_id"] == draft_version.id
      assert payload["quality_control_id"] == quality_control.id
      assert payload["status"] == "published"
      assert payload["action"] == "publish"
      assert versioned_event.event == "quality_control_version_status_updated"
      assert versioned_event.resource_type == "quality_control"
      assert versioned_event.resource_id == to_string(quality_control.id)

      payload = Jason.decode!(versioned_event.payload)
      assert payload["quality_control_version_id"] == published_version.id
      assert payload["quality_control_id"] == quality_control.id
      assert payload["status"] == "versioned"
      assert payload["action"] == "publish"
    end

    test "publishes pending_approval version" do
      quality_control = insert(:quality_control)

      template_name = "df_type"

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: [%{"name" => "group", "fields" => [%{"name" => "foo"}]}]}}
      )

      pending_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "pending_approval",
          version: 1,
          name: "Pending Control",
          df_type: template_name,
          dynamic_content: %{"foo" => %{"value" => "bar", "origin" => "user"}},
          control_mode: "percentage",
          score_criteria: string_params_for(:sc_percentage),
          control_properties: string_params_for(:cp_ratio_params_for)
        )

      quality_control =
        QualityControls.get_quality_control!(quality_control.id, preload: :published_version)

      assert {:ok, %QualityControlVersion{status: "published"}} =
               QualityControlWorkflow.update_quality_control_status(quality_control, "publish")

      updated = Repo.get!(QualityControlVersion, pending_version.id)
      assert updated.status == "published"

      assert {:ok, [published_event]} =
               Stream.read(:redix, @audit_stream, count: 1, transform: true)

      assert published_event.event == "quality_control_version_status_updated"
      assert published_event.resource_type == "quality_control"
      assert published_event.resource_id == to_string(quality_control.id)
      payload = Jason.decode!(published_event.payload)
      assert payload["quality_control_version_id"] == pending_version.id
      assert payload["quality_control_id"] == quality_control.id
      assert payload["status"] == "published"
      assert payload["action"] == "publish"
    end

    test "rejects pending_approval version" do
      quality_control = insert(:quality_control)

      pending_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "pending_approval",
          version: 1
        )

      quality_control =
        QualityControls.get_quality_control!(quality_control.id, preload: :published_version)

      assert {:ok, %QualityControlVersion{status: "rejected"}} =
               QualityControlWorkflow.update_quality_control_status(quality_control, "reject")

      updated = Repo.get!(QualityControlVersion, pending_version.id)
      assert updated.status == "rejected"

      assert {:ok, [rejected_event]} =
               Stream.read(:redix, @audit_stream, count: 1, transform: true)

      assert rejected_event.event == "quality_control_version_status_updated"
      assert rejected_event.resource_type == "quality_control"
      assert rejected_event.resource_id == to_string(quality_control.id)
      payload = Jason.decode!(rejected_event.payload)
      assert payload["quality_control_version_id"] == pending_version.id
      assert payload["quality_control_id"] == quality_control.id
      assert payload["status"] == "rejected"
      assert payload["action"] == "reject"
    end

    test "sends rejected version back to draft" do
      quality_control = insert(:quality_control)

      rejected_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "rejected",
          version: 1
        )

      quality_control =
        QualityControls.get_quality_control!(quality_control.id, preload: :published_version)

      assert {:ok, %QualityControlVersion{status: "draft"}} =
               QualityControlWorkflow.update_quality_control_status(
                 quality_control,
                 "send_to_draft"
               )

      updated = Repo.get!(QualityControlVersion, rejected_version.id)
      assert updated.status == "draft"

      assert {:ok, [draft_event]} = Stream.read(:redix, @audit_stream, count: 1, transform: true)
      assert draft_event.event == "quality_control_version_status_updated"
      assert draft_event.resource_type == "quality_control"
      assert draft_event.resource_id == to_string(quality_control.id)
      payload = Jason.decode!(draft_event.payload)
      assert payload["quality_control_version_id"] == rejected_version.id
      assert payload["quality_control_id"] == quality_control.id
      assert payload["status"] == "draft"
      assert payload["action"] == "send_to_draft"
    end

    test "sends draft to pending_approval" do
      quality_control = insert(:quality_control)

      template_name = "df_type"

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: [%{"name" => "group", "fields" => [%{"name" => "foo"}]}]}}
      )

      draft_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "draft",
          version: 1,
          df_type: template_name,
          dynamic_content: %{"foo" => %{"value" => "bar", "origin" => "user"}},
          control_mode: "percentage",
          score_criteria: string_params_for(:sc_percentage),
          control_properties: string_params_for(:cp_ratio_params_for)
        )

      quality_control =
        QualityControls.get_quality_control!(quality_control.id, preload: :published_version)

      assert {:ok, %QualityControlVersion{status: "pending_approval"}} =
               QualityControlWorkflow.update_quality_control_status(
                 quality_control,
                 "send_to_approval"
               )

      updated = Repo.get!(QualityControlVersion, draft_version.id)
      assert updated.status == "pending_approval"

      assert {:ok, [pending_approval_event]} =
               Stream.read(:redix, @audit_stream, count: 1, transform: true)

      assert pending_approval_event.event == "quality_control_version_status_updated"
      assert pending_approval_event.resource_type == "quality_control"
      assert pending_approval_event.resource_id == to_string(quality_control.id)
      payload = Jason.decode!(pending_approval_event.payload)
      assert payload["quality_control_version_id"] == draft_version.id
      assert payload["quality_control_id"] == quality_control.id
      assert payload["status"] == "pending_approval"
      assert payload["action"] == "send_to_approval"
    end

    test "deprecates published version without draft" do
      quality_control = insert(:quality_control)

      published_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "published",
          version: 1
        )

      quality_control =
        QualityControls.get_quality_control!(quality_control.id, preload: :published_version)

      assert {:ok, %QualityControlVersion{status: "deprecated"}} =
               QualityControlWorkflow.update_quality_control_status(quality_control, "deprecate")

      updated = Repo.get!(QualityControlVersion, published_version.id)
      assert updated.status == "deprecated"

      assert {:ok, [deprecated_event]} =
               Stream.read(:redix, @audit_stream, count: 1, transform: true)

      assert deprecated_event.event == "quality_control_version_status_updated"
      assert deprecated_event.resource_type == "quality_control"
      assert deprecated_event.resource_id == to_string(quality_control.id)
      payload = Jason.decode!(deprecated_event.payload)
      assert payload["quality_control_version_id"] == published_version.id
      assert payload["quality_control_id"] == quality_control.id
      assert payload["status"] == "deprecated"
      assert payload["action"] == "deprecate"
    end

    test "deprecates published version and deletes draft" do
      quality_control = insert(:quality_control)

      published_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "published",
          version: 1
        )

      draft_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "draft",
          version: 2
        )

      quality_control =
        QualityControls.get_quality_control!(quality_control.id, preload: :published_version)

      assert {:ok, %QualityControlVersion{status: "deprecated"}} =
               QualityControlWorkflow.update_quality_control_status(quality_control, "deprecate")

      updated = Repo.get!(QualityControlVersion, published_version.id)
      assert updated.status == "deprecated"

      refute Repo.get(QualityControlVersion, draft_version.id)

      assert {:ok, [deleted_event, deprecated_event]} =
               Stream.read(:redix, @audit_stream, count: 2, transform: true)

      assert deleted_event.event == "quality_control_version_status_updated"
      assert deleted_event.resource_type == "quality_control"
      assert deleted_event.resource_id == to_string(quality_control.id)
      payload = Jason.decode!(deleted_event.payload)
      assert payload["quality_control_version_id"] == draft_version.id
      assert payload["quality_control_id"] == quality_control.id
      assert payload["status"] == "draft"
      assert payload["action"] == "deprecate"
      assert deprecated_event.event == "quality_control_version_status_updated"
      assert deprecated_event.resource_type == "quality_control"
      assert deprecated_event.resource_id == to_string(quality_control.id)
      payload = Jason.decode!(deprecated_event.payload)
      assert payload["quality_control_version_id"] == published_version.id
      assert payload["quality_control_id"] == quality_control.id
      assert payload["status"] == "deprecated"
      assert payload["action"] == "deprecate"
    end

    test "restores deprecated version" do
      quality_control = insert(:quality_control)

      deprecated_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "deprecated",
          version: 1
        )

      quality_control =
        QualityControls.get_quality_control!(quality_control.id, preload: :published_version)

      assert {:ok, %QualityControlVersion{status: "published"}} =
               QualityControlWorkflow.update_quality_control_status(quality_control, "restore")

      updated = Repo.get!(QualityControlVersion, deprecated_version.id)
      assert updated.status == "published"

      assert {:ok, [published_event]} =
               Stream.read(:redix, @audit_stream, count: 1, transform: true)

      assert published_event.event == "quality_control_version_status_updated"
      assert published_event.resource_type == "quality_control"
      assert published_event.resource_id == to_string(quality_control.id)
      payload = Jason.decode!(published_event.payload)
      assert payload["quality_control_version_id"] == deprecated_version.id
      assert payload["quality_control_id"] == quality_control.id
      assert payload["status"] == "published"
      assert payload["action"] == "restore"
    end

    test "returns error when publish validation fails" do
      quality_control = insert(:quality_control)

      draft_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "draft",
          version: 1,
          dynamic_content: nil,
          df_type: nil,
          score_criteria: nil,
          control_properties: nil
        )

      quality_control =
        QualityControls.get_quality_control!(quality_control.id, preload: :published_version)

      assert {:error, %{errors: errors}} =
               QualityControlWorkflow.update_quality_control_status(quality_control, "publish")

      assert errors[:df_type] == {"can't be blank", [validation: :required]}
      assert errors[:dynamic_content] == {"can't be blank", [validation: :required]}
      assert errors[:score_criteria] == {"can't be blank", [validation: :required]}
      assert errors[:control_properties] == {"can't be blank", [validation: :required]}

      unchanged = Repo.get!(QualityControlVersion, draft_version.id)
      assert unchanged.status == "draft"
      assert {:ok, []} == Stream.read(:redix, @audit_stream, count: 1, transform: true)
    end

    test "returns error for invalid action" do
      quality_control = insert(:quality_control)

      _draft_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "draft",
          version: 1
        )

      quality_control =
        QualityControls.get_quality_control!(quality_control.id, preload: :published_version)

      assert {:error, :invalid_action, "invalid_action"} =
               QualityControlWorkflow.update_quality_control_status(
                 quality_control,
                 "invalid_action"
               )

      assert {:ok, []} == Stream.read(:redix, @audit_stream, count: 1, transform: true)
    end

    test "returns error for invalid quality control" do
      assert {:error, :invalid_quality_control} =
               QualityControlWorkflow.update_quality_control_status(nil, "publish")

      assert {:ok, []} == Stream.read(:redix, @audit_stream, count: 1, transform: true)
    end

    test "calls reindex after status update" do
      quality_control = insert(:quality_control)

      _rejected_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "rejected",
          version: 1
        )

      quality_control =
        QualityControls.get_quality_control!(quality_control.id, preload: :published_version)

      IndexWorkerMock.clear()

      assert {:ok, %QualityControlVersion{status: "draft"}} =
               QualityControlWorkflow.update_quality_control_status(
                 quality_control,
                 "send_to_draft"
               )

      assert IndexWorkerMock.calls() == [
               {:reindex, :quality_control_versions,
                [{:quality_control_ids, [quality_control.id]}]}
             ]
    end

    test "preloads quality_control in returned version" do
      quality_control = insert(:quality_control)

      _rejected_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "rejected",
          version: 1
        )

      quality_control =
        QualityControls.get_quality_control!(quality_control.id, preload: :published_version)

      assert {:ok, %QualityControlVersion{quality_control: %QualityControl{} = preloaded_qc}} =
               QualityControlWorkflow.update_quality_control_status(
                 quality_control,
                 "send_to_draft"
               )

      assert preloaded_qc.id == quality_control.id
    end
  end

  describe "update_quality_control_draft/2" do
    test "updates draft version successfully" do
      quality_control = insert(:quality_control, domain_ids: [1, 2], source_id: 10)

      draft_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "draft",
          version: 1,
          name: "Original Name",
          control_mode: "percentage",
          df_type: "old_type",
          dynamic_content: %{"old" => "content"}
        )

      params = %{
        "name" => "Updated Name",
        "control_mode" => "count",
        "df_type" => "new_type",
        "dynamic_content" => %{"new" => "content"},
        "score_criteria" => string_params_for(:sc_count),
        "control_properties" => string_params_for(:cp_count)
      }

      IndexWorkerMock.clear()

      assert {:ok, %QualityControlVersion{name: "Updated Name", control_mode: "count"}} =
               QualityControlWorkflow.update_quality_control_draft(draft_version, params)

      updated = Repo.get!(QualityControlVersion, draft_version.id)
      assert updated.name == "Updated Name"
      assert updated.control_mode == "count"
      assert updated.df_type == "new_type"
      assert updated.dynamic_content == %{"new" => "content"}

      assert IndexWorkerMock.calls() == [
               {:reindex, :quality_control_versions,
                [{:quality_control_ids, [quality_control.id]}]}
             ]
    end

    test "publishes audit event when updating draft" do
      quality_control = insert(:quality_control, domain_ids: [1], source_id: 10)

      draft_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "draft",
          version: 1,
          name: "Draft Control",
          control_mode: "percentage",
          dynamic_content: %{"foo" => %{"value" => "bar", "origin" => "user"}}
        )

      params = %{
        "name" => "Updated Draft",
        "control_mode" => "percentage",
        "df_type" => "some_type",
        "dynamic_content" => %{},
        "score_criteria" => string_params_for(:sc_percentage),
        "control_properties" => string_params_for(:cp_ratio_params_for)
      }

      assert {:ok, updated_version} =
               QualityControlWorkflow.update_quality_control_draft(draft_version, params)

      assert {:ok, [event]} = Stream.read(:redix, @audit_stream, count: 1, transform: true)
      assert event.event == "quality_control_version_draft_updated"
      assert event.resource_type == "quality_control"
      assert event.resource_id == to_string(quality_control.id)

      payload = Jason.decode!(event.payload)
      assert payload["quality_control_version_id"] == updated_version.id
      assert payload["quality_control_id"] == quality_control.id
      assert payload["changes"]["name"] == "Updated Draft"
      assert payload["changes"]["df_type"] == "some_type"
      assert payload["changes"]["dynamic_content"] == %{}
    end

    test "returns error when version is not a draft" do
      quality_control = insert(:quality_control)

      published_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "published",
          version: 1
        )

      params = %{"name" => "Updated Name"}

      assert {:error, :invalid_action, "update_draft not a draft"} =
               QualityControlWorkflow.update_quality_control_draft(published_version, params)

      # Verify no audit event was published
      assert {:ok, []} = Stream.read(:redix, @audit_stream, count: 1, transform: true)
    end

    test "validates required fields" do
      quality_control = insert(:quality_control)

      draft_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "draft",
          version: 1,
          name: "Draft Control"
        )

      assert {:error, %{errors: errors}} =
               QualityControlWorkflow.update_quality_control_draft(draft_version, %{name: nil})

      assert errors[:name] == {"can't be blank", [validation: :required]}
    end

    test "validates unique name constraint" do
      quality_control = insert(:quality_control)

      _existing_version =
        insert(:quality_control_version,
          quality_control: build(:quality_control),
          name: "Existing Name",
          status: "draft",
          version: 1
        )

      draft_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "draft",
          version: 1,
          name: "Original Name"
        )

      params = %{
        "name" => "Existing Name",
        "control_mode" => "percentage"
      }

      assert {:error, %{errors: errors}} =
               QualityControlWorkflow.update_quality_control_draft(draft_version, params)

      assert [name: {"duplicated_name", []}] = errors
    end

    test "updates score_criteria and control_properties" do
      quality_control = insert(:quality_control)

      draft_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "draft",
          version: 1,
          control_mode: "percentage"
        )

      params =
        %{
          "name" => "Updated Control",
          "control_mode" => "count",
          "df_type" => "some_type",
          "dynamic_content" => %{},
          "score_criteria" => string_params_for(:sc_count),
          "control_properties" => string_params_for(:cp_count)
        }

      assert {:ok, _updated_version} =
               QualityControlWorkflow.update_quality_control_draft(draft_version, params)

      updated = Repo.get!(QualityControlVersion, draft_version.id)
      assert updated.control_mode == "count"
      assert updated.score_criteria.count.goal == params["score_criteria"]["goal"]
      assert updated.score_criteria.count.maximum == params["score_criteria"]["maximum"]

      assert updated.control_properties.count.errors_resource.id ==
               params["control_properties"]["errors_resource"]["id"]

      assert updated.control_properties.count.errors_resource.type ==
               params["control_properties"]["errors_resource"]["type"]
    end

    test "updates only specified fields" do
      quality_control = insert(:quality_control)

      draft_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "draft",
          version: 1,
          name: "Original Name",
          control_mode: "percentage",
          df_type: "original_type",
          dynamic_content: %{"original" => "content"}
        )

      params = %{
        "name" => "Updated Name",
        "control_mode" => "percentage",
        "df_type" => "original_type",
        "dynamic_content" => %{"original" => "content"},
        "score_criteria" => string_params_for(:sc_percentage),
        "control_properties" => string_params_for(:cp_ratio_params_for)
      }

      assert {:ok, _updated_version} =
               QualityControlWorkflow.update_quality_control_draft(draft_version, params)

      updated = Repo.get!(QualityControlVersion, draft_version.id)
      assert updated.name == "Updated Name"
      assert updated.control_mode == "percentage"
      assert updated.df_type == "original_type"
      assert updated.dynamic_content == %{"original" => "content"}
    end

    test "preloads quality_control in returned version" do
      quality_control = insert(:quality_control)

      draft_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "draft",
          version: 1
        )

      params = %{
        "name" => "Updated Name",
        "control_mode" => "percentage",
        "df_type" => "some_type",
        "dynamic_content" => %{},
        "score_criteria" => string_params_for(:sc_percentage),
        "control_properties" => string_params_for(:cp_ratio_params_for)
      }

      assert {:ok,
              %QualityControlVersion{
                quality_control: %QualityControl{} = preloaded_qc
              }} = QualityControlWorkflow.update_quality_control_draft(draft_version, params)

      assert preloaded_qc.id == quality_control.id
    end

    test "handles validation errors gracefully" do
      quality_control = insert(:quality_control)

      draft_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "draft",
          version: 1,
          name: "Draft Control"
        )

      params = %{
        "name" => "Updated Name",
        "control_mode" => "invalid_mode",
        "score_criteria" => string_params_for(:sc_percentage)
      }

      assert {:error, %{changes: %{score_criteria: %{errors: errors}}}} =
               QualityControlWorkflow.update_quality_control_draft(draft_version, params)

      assert errors[:control_mode] == {"invalid", []}
      assert {:ok, []} = Stream.read(:redix, @audit_stream, count: 1, transform: true)
    end

    test "does not update status field" do
      quality_control = insert(:quality_control)

      draft_version =
        insert(:quality_control_version,
          quality_control: quality_control,
          status: "draft",
          version: 1
        )

      params = %{
        "name" => "Updated Name",
        "status" => "published",
        "control_mode" => "percentage",
        "df_type" => "some_type",
        "dynamic_content" => %{},
        "score_criteria" => string_params_for(:sc_percentage),
        "control_properties" => string_params_for(:cp_ratio_params_for)
      }

      assert {:ok, _updated_version} =
               QualityControlWorkflow.update_quality_control_draft(draft_version, params)

      # Status should remain "draft" - update_draft_changeset doesn't allow status changes
      updated = Repo.get!(QualityControlVersion, draft_version.id)
      assert updated.status == "draft"
    end
  end
end
