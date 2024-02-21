defmodule TdQx.QualityControlWorkflowTest do
  use TdQx.DataCase

  alias TdCluster.TestHelpers.TdDfMock
  alias TdCore.Search.IndexWorkerMock
  alias TdQx.QualityControls
  alias TdQx.QualityControls.QualityControl
  alias TdQx.QualityControls.QualityControlVersion
  alias TdQx.QualityControlWorkflow

  describe "create_quality_control/1" do
    test "creates quality control and its version" do
      params = %{
        "domain_ids" => [1, 2],
        "name" => "some name"
      }

      assert {:ok,
              %QualityControlVersion{
                name: "some name",
                quality_control: %QualityControl{
                  domain_ids: [1, 2]
                }
              }} = QualityControlWorkflow.create_quality_control(params)
    end

    test "validates quality control unique name and status" do
      %{name: name} =
        insert(:quality_control_version,
          quality_control: insert(:quality_control)
        )

      assert {:error, %{errors: errors}} =
               QualityControlWorkflow.create_quality_control(%{name: name, domain_ids: [1, 2]})

      assert [name: {"duplicated_name", []}] = errors
    end

    test "validates quality control unique name" do
      %{name: name} =
        insert(:quality_control_version,
          status: "published",
          quality_control: insert(:quality_control)
        )

      assert {:error, %{errors: errors}} =
               QualityControlWorkflow.create_quality_control(%{name: name, domain_ids: [1, 2]})

      assert [name: {"duplicated_name", []}] = errors
    end

    test "validates quality control required fields" do
      assert {:error, %{errors: errors}} = QualityControlWorkflow.create_quality_control(%{})

      assert [domain_ids: {"can't be blank", [validation: :required]}] = errors

      assert {:error, %{errors: errors}} =
               QualityControlWorkflow.create_quality_control(%{domain_ids: [1, 2]})

      assert [name: {"can't be blank", [validation: :required]}] = errors
    end

    test "calls reindex after creation" do
      params = %{
        "domain_ids" => [1, 2],
        "name" => "some name"
      }

      IndexWorkerMock.clear()

      assert {:ok,
              %QualityControlVersion{
                quality_control_id: id,
                name: "some name",
                quality_control: %QualityControl{
                  domain_ids: [1, 2]
                }
              }} = QualityControlWorkflow.create_quality_control(params)

      assert IndexWorkerMock.calls() == [{:reindex, :quality_controls, [id]}]
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
            df_content: nil,
            df_type: nil,
            result_criteria: nil,
            result_type: nil,
            resource: nil,
            validation: [],
            quality_control: insert(:quality_control)
          )

        changeset = QualityControlVersion.status_changeset(quality_control_version, target_status)

        assert {:update, %{valid?: false, errors: errors}} =
                 QualityControlWorkflow.validate_publish_changeset(
                   {:update, changeset},
                   "publish"
                 )

        assert [
                 {:validation, {"can't be blank", [validation: :required]}},
                 {:resource, {"can't be blank", [validation: :required]}},
                 {:result_criteria, {"can't be blank", [validation: :required]}},
                 {:df_content, {"can't be blank", [validation: :required]}},
                 {:df_type, {"can't be blank", [validation: :required]}},
                 {:result_type, {"can't be blank", [validation: :required]}}
               ] = errors
      end
    end

    test "handles invalid template not found" do
      template_name = "df_type"

      TdDfMock.get_template_by_name!(&Mox.expect/4, template_name, {:ok, nil})

      quality_control_version =
        insert(:quality_control_version,
          df_content: %{"foo" => "bar"},
          df_type: template_name,
          result_criteria: %{},
          result_type: "result_type",
          resource: build(:resource),
          validation: [build(:clause)],
          quality_control: insert(:quality_control)
        )

      changeset = QualityControlVersion.status_changeset(quality_control_version, "published")

      assert {:update, %{valid?: false, errors: errors}} =
               QualityControlWorkflow.validate_publish_changeset({:update, changeset}, "publish")

      assert [df_content: {"invalid template", [reason: :template_not_found]}] == errors
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
          df_content: %{"not_foo" => "bar"},
          df_type: template_name,
          result_criteria: %{},
          result_type: "result_type",
          resource: build(:resource),
          validation: [build(:clause)],
          quality_control: insert(:quality_control)
        )

      changeset = QualityControlVersion.status_changeset(quality_control_version, "published")

      assert {:update, %{valid?: false, errors: errors}} =
               QualityControlWorkflow.validate_publish_changeset({:update, changeset}, "publish")

      assert [
               df_content:
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
            df_content: %{"foo" => "bar"},
            df_type: template_name,
            result_criteria: %{},
            result_type: "result_type",
            resource: build(:resource),
            validation: [build(:clause)],
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
            df_content: nil,
            df_type: nil,
            resource: nil,
            result_criteria: nil,
            result_type: nil,
            validation: [],
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
          df_content: nil,
          df_type: nil,
          resource: nil,
          result_criteria: nil,
          result_type: nil,
          validation: [],
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
end
