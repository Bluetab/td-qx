defmodule TdQx.QualityControls.QualityControlVersionTest do
  use TdQx.DataCase

  alias TdCluster.TestHelpers.TdDfMock
  alias TdQx.QualityControls.QualityControlVersion

  describe "create_changeset/3" do
    test "validates required fields" do
      quality_control = insert(:quality_control)
      params = %{}

      assert %{valid?: false, errors: errors} =
               QualityControlVersion.create_changeset(quality_control, params, 1)

      assert [name: {"can't be blank", [{:validation, :required}]}] = errors
    end

    test "validates duplicated name" do
      quality_control = insert(:quality_control)
      %{name: used_name} = insert(:quality_control_version)
      params = %{name: used_name}

      assert %{valid?: false, errors: errors} =
               QualityControlVersion.create_changeset(quality_control, params, 1)

      assert [name: {"duplicated_name", []}] = errors
    end

    test "allows same name for same quality_control" do
      quality_control = insert(:quality_control)

      %{name: used_name} =
        insert(:quality_control_version, status: "published", quality_control: quality_control)

      params = %{name: used_name}

      assert %{valid?: true, errors: errors} =
               QualityControlVersion.create_changeset(quality_control, params, 1)

      assert [] == errors
    end

    test "validates resource field" do
      quality_control = insert(:quality_control)

      params = %{
        name: "name",
        resource: %{}
      }

      assert %{valid?: false} =
               changeset = QualityControlVersion.create_changeset(quality_control, params, 1)

      assert %{resource: %{id: ["can't be blank"], type: ["can't be blank"]}} =
               errors_on(changeset)
    end

    test "valid resource field" do
      quality_control = insert(:quality_control)

      params = %{
        name: "name",
        resource: %{
          id: 1,
          type: "data_view"
        }
      }

      assert %{valid?: true} = QualityControlVersion.create_changeset(quality_control, params, 1)
    end

    test "validates validation field" do
      quality_control = insert(:quality_control)

      params = %{
        name: "name",
        validation: [%{}]
      }

      assert %{valid?: false} =
               changeset = QualityControlVersion.create_changeset(quality_control, params, 1)

      assert %{validation: [%{expressions: ["can't be blank"]}]} = errors_on(changeset)
    end

    test "valid validation field" do
      quality_control = insert(:quality_control)

      params = %{
        name: "name",
        validation: [params_for(:clause_params_for)]
      }

      assert %{valid?: true} = QualityControlVersion.create_changeset(quality_control, params, 1)
    end
  end

  describe "status_changeset/2" do
    test "only changes status field" do
      quality_control_version = insert(:quality_control_version)

      assert %{valid?: true, changes: changes} =
               QualityControlVersion.status_changeset(quality_control_version, "pending_approval")

      assert changes == %{status: "pending_approval"}
    end

    test "validates status" do
      quality_control_version = insert(:quality_control_version)

      assert %{valid?: false, errors: errors} =
               QualityControlVersion.status_changeset(quality_control_version, "invalid_status")

      assert [
               status:
                 {"is invalid",
                  [
                    validation: :inclusion,
                    enum: [
                      "draft",
                      "pending_approval",
                      "rejected",
                      "published",
                      "versioned",
                      "deprecated"
                    ]
                  ]}
             ] = errors
    end
  end

  describe "validate_publish_changeset/1" do
    test "validates all required fields" do
      quality_control_version =
        insert(:quality_control_version,
          df_content: nil,
          df_type: nil,
          result_criteria: nil,
          result_type: nil,
          resource: nil,
          validation: []
        )

      changeset = QualityControlVersion.status_changeset(quality_control_version, "published")

      assert %{valid?: false, errors: errors} =
               QualityControlVersion.validate_publish_changeset(changeset)

      assert [
               {:validation, {"can't be blank", [validation: :required]}},
               {:resource, {"can't be blank", [validation: :required]}},
               {:result_criteria, {"can't be blank", [validation: :required]}},
               {:df_content, {"can't be blank", [validation: :required]}},
               {:df_type, {"can't be blank", [validation: :required]}},
               {:result_type, {"can't be blank", [validation: :required]}}
             ] = errors
    end

    test "valid required fields" do
      template_name = "df_type"

      TdDfMock.get_template_by_name!(
        &Mox.expect/4,
        template_name,
        {:ok, %{content: [%{"name" => "group", "fields" => [%{"name" => "foo"}]}]}}
      )

      quality_control_version =
        insert(:quality_control_version, df_type: template_name, df_content: %{"foo" => "bar"})

      changeset = QualityControlVersion.status_changeset(quality_control_version, "published")

      assert %{valid?: true, errors: errors} =
               QualityControlVersion.validate_publish_changeset(changeset)

      assert [] == errors
    end
  end
end
