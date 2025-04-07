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

      assert [
               name: {"can't be blank", [{:validation, :required}]},
               control_mode: {"can't be blank", [validation: :required]}
             ] = errors
    end

    test "validates duplicated name" do
      quality_control = insert(:quality_control)

      %{name: used_name} =
        insert(:quality_control_version, quality_control: insert(:quality_control))

      params = %{name: used_name, control_mode: "percentage"}

      assert %{valid?: false, errors: errors} =
               QualityControlVersion.create_changeset(quality_control, params, 1)

      assert [name: {"duplicated_name", []}] = errors
    end

    test "allows same name for same quality_control" do
      quality_control = insert(:quality_control)

      %{name: used_name} =
        insert(:quality_control_version,
          status: "published",
          quality_control: quality_control
        )

      params = %{name: used_name, control_mode: "percentage"}

      assert %{valid?: true, errors: errors} =
               QualityControlVersion.create_changeset(quality_control, params, 1)

      assert [] == errors
    end

    test "validates resource field for percentage control_mode" do
      quality_control = insert(:quality_control)

      params = %{
        name: "name",
        control_mode: "percentage",
        control_properties: %{
          resource: %{}
        }
      }

      assert %{valid?: false} =
               changeset = QualityControlVersion.create_changeset(quality_control, params, 1)

      assert %{
               control_properties: %{
                 ratio: %{resource: %{id: ["can't be blank"], type: ["can't be blank"]}}
               }
             } =
               errors_on(changeset)
    end

    test "validates validation field for percentage control_mode" do
      quality_control = insert(:quality_control)

      params = %{
        name: "name",
        control_mode: "percentage",
        control_properties: %{
          validation: [%{}]
        }
      }

      assert %{valid?: false} =
               changeset = QualityControlVersion.create_changeset(quality_control, params, 1)

      assert %{
               control_properties: %{
                 ratio: %{validation: [%{expressions: ["can't be blank"]}]}
               }
             } =
               errors_on(changeset)
    end

    test "validates resource field for deviation control_mode" do
      quality_control = insert(:quality_control)

      params = %{
        name: "name",
        control_mode: "deviation",
        control_properties: %{
          resource: %{}
        }
      }

      assert %{valid?: false} =
               changeset = QualityControlVersion.create_changeset(quality_control, params, 1)

      assert %{
               control_properties: %{
                 ratio: %{resource: %{id: ["can't be blank"], type: ["can't be blank"]}}
               }
             } =
               errors_on(changeset)
    end

    test "validates validation field for deviation control_mode" do
      quality_control = insert(:quality_control)

      params = %{
        name: "name",
        control_mode: "deviation",
        control_properties: %{
          validation: [%{}]
        }
      }

      assert %{valid?: false} =
               changeset = QualityControlVersion.create_changeset(quality_control, params, 1)

      assert %{
               control_properties: %{
                 ratio: %{validation: [%{expressions: ["can't be blank"]}]}
               }
             } =
               errors_on(changeset)
    end

    test "validates errors_resource field for count control_mode" do
      quality_control = insert(:quality_control)

      params = %{
        name: "name",
        control_mode: "count",
        control_properties: %{
          errors_resource: %{}
        }
      }

      assert %{valid?: false} =
               changeset = QualityControlVersion.create_changeset(quality_control, params, 1)

      assert %{
               control_properties: %{
                 count: %{
                   errors_resource: %{id: ["can't be blank"], type: ["can't be blank"]}
                 }
               }
             } =
               errors_on(changeset)
    end

    test "valid control_properties field for percentage control_mode" do
      quality_control = insert(:quality_control)

      params = %{
        name: "name",
        control_mode: "percentage",
        control_properties: %{
          resource: %{
            id: 1,
            type: "data_view"
          },
          validation: [params_for(:clause_params_for)]
        }
      }

      assert %{valid?: true} = QualityControlVersion.create_changeset(quality_control, params, 1)
    end

    test "valid control_properties field for deviation control_mode" do
      quality_control = insert(:quality_control)

      params = %{
        name: "name",
        control_mode: "deviation",
        control_properties: %{
          resource: %{
            id: 1,
            type: "data_view"
          },
          validation: [params_for(:clause_params_for)]
        }
      }

      assert %{valid?: true} = QualityControlVersion.create_changeset(quality_control, params, 1)
    end

    test "valid control_properties field for count control_mode" do
      quality_control = insert(:quality_control)

      params = %{
        name: "name",
        control_mode: "count",
        control_properties: %{
          errors_resource: %{
            id: 1,
            type: "data_view"
          }
        }
      }

      assert %{valid?: true} = QualityControlVersion.create_changeset(quality_control, params, 1)
    end

    test "valid control_properties field for error_count control_mode" do
      quality_control = insert(:quality_control)

      params = %{
        name: "name",
        control_mode: "error_count",
        control_properties: %{
          resource: %{
            id: 1,
            type: "data_view"
          },
          validation: [params_for(:clause_params_for)]
        }
      }

      assert %{valid?: true} = QualityControlVersion.create_changeset(quality_control, params, 1)
    end

    test "validates resource field for error_count control_mode" do
      quality_control = insert(:quality_control)

      params = %{
        name: "name",
        control_mode: "error_count",
        control_properties: %{
          resource: %{}
        }
      }

      assert %{valid?: false} =
               changeset = QualityControlVersion.create_changeset(quality_control, params, 1)

      assert %{
               control_properties: %{
                 ratio: %{resource: %{id: ["can't be blank"], type: ["can't be blank"]}}
               }
             } =
               errors_on(changeset)
    end

    test "validates validation field for error_count control_mode" do
      quality_control = insert(:quality_control)

      params = %{
        name: "name",
        control_mode: "error_count",
        control_properties: %{
          validation: [%{}]
        }
      }

      assert %{valid?: false} =
               changeset = QualityControlVersion.create_changeset(quality_control, params, 1)

      assert %{
               control_properties: %{
                 ratio: %{validation: [%{expressions: ["can't be blank"]}]}
               }
             } =
               errors_on(changeset)
    end
  end

  describe "status_changeset/2" do
    test "only changes status field" do
      quality_control_version =
        insert(:quality_control_version, quality_control: insert(:quality_control))

      assert %{valid?: true, changes: changes} =
               QualityControlVersion.status_changeset(quality_control_version, "pending_approval")

      assert changes == %{status: "pending_approval"}
    end

    test "validates status" do
      quality_control_version =
        insert(:quality_control_version, quality_control: insert(:quality_control))

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
          dynamic_content: nil,
          df_type: nil,
          score_criteria: nil,
          control_properties: nil,
          control_mode: nil,
          quality_control: insert(:quality_control)
        )

      changeset = QualityControlVersion.status_changeset(quality_control_version, "published")

      assert %{valid?: false, errors: errors} =
               QualityControlVersion.validate_publish_changeset(changeset)

      assert [
               {:control_properties, {"can't be blank", [validation: :required]}},
               {:score_criteria, {"can't be blank", [validation: :required]}},
               {:dynamic_content, {"can't be blank", [validation: :required]}},
               {:df_type, {"can't be blank", [validation: :required]}},
               {:control_mode, {"can't be blank", [validation: :required]}}
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
        insert(:quality_control_version,
          df_type: template_name,
          dynamic_content: %{"foo" => %{"value" => "bar", "origin" => "user"}},
          quality_control: insert(:quality_control)
        )

      changeset = QualityControlVersion.status_changeset(quality_control_version, "published")

      assert %{valid?: true, errors: errors} =
               QualityControlVersion.validate_publish_changeset(changeset)

      assert [] == errors
    end
  end
end
