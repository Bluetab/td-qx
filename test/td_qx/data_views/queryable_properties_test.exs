defmodule TdQx.DataViews.QueryablePropertiesTest do
  use TdQx.DataCase

  import QueryableHelpers

  alias TdQx.DataViews.QueryableProperties
  alias TdQxWeb.ChangesetJSON

  describe "QueryableProperties changeset" do
    for type <- ~w|from join select where group_by| do
      @tag type: type
      test "test valid changeset for queryable type '#{type}'", %{type: type} do
        params = valid_properties_for(type)

        assert %{valid?: true} =
                 QueryableProperties.changeset(%QueryableProperties{}, params, type)
      end
    end

    test "test invalid queryable type" do
      params = %{}

      assert %{valid?: false, errors: errors} =
               QueryableProperties.changeset(%QueryableProperties{}, params, "invalid")

      assert [properties_type: {"invalid", []}] = errors
    end
  end

  describe "Join QueryableProperties tests" do
    for type <- ~w|inner full_outer left right| do
      @tag type: type
      test "test valid join type '#{type}' on queryable changeset", %{type: type} do
        params = string_params_for(:qp_join_params_for, type: type)

        assert %{valid?: true} =
                 QueryableProperties.changeset(%QueryableProperties{}, params, "join")
      end
    end

    test "test invalid join type" do
      params = string_params_for(:qp_join_params_for, type: "invalid type")

      assert %{valid?: false} =
               changeset = QueryableProperties.changeset(%QueryableProperties{}, params, "join")

      %{errors: errors} = ChangesetJSON.error(%{changeset: changeset})
      assert %{join: %{type: ["is invalid"]}} = errors
    end

    test "test invalid properties 'from'" do
      params = %{}

      assert %{valid?: false} =
               changeset = QueryableProperties.changeset(%QueryableProperties{}, params, "from")

      %{errors: errors} = ChangesetJSON.error(%{changeset: changeset})

      assert %{from: %{resource: ["can't be blank"]}} = errors
    end
  end

  describe "GroupBy QueryableProperties tests" do
    test "test invalid non function expression on aggregate field" do
      params =
        string_params_for(:qp_group_by_params_for,
          aggregate_fields: [build(:qp_select_field_params_for)]
        )

      assert %{valid?: false} =
               changeset =
               QueryableProperties.changeset(%QueryableProperties{}, params, "group_by")

      %{errors: errors} = ChangesetJSON.error(%{changeset: changeset})

      assert %{
               group_by: %{
                 aggregate_fields: [
                   %{expression: %{shape: ["invalid shape for aggregated field"]}}
                 ]
               }
             } = errors
    end

    test "test invalid non aggregator function on aggregate field" do
      params = string_params_for(:qp_group_by_params_for)

      %{
        "aggregate_fields" => [
          %{
            "expression" => %{
              "value" => %{
                "name" => function_name,
                "type" => function_type
              }
            }
          }
        ]
      } = params

      insert(:function, name: function_name, type: function_type, class: "not_aggregator")

      assert %{valid?: false} =
               changeset =
               QueryableProperties.changeset(%QueryableProperties{}, params, "group_by")

      %{errors: errors} = ChangesetJSON.error(%{changeset: changeset})

      assert %{
               group_by: %{
                 aggregate_fields: [
                   %{
                     expression: %{
                       value: %{
                         function: %{class: ["invalid function class for aggregator function"]}
                       }
                     }
                   }
                 ]
               }
             } = errors
    end

    test "test invalid duplicated alias" do
      params =
        string_params_for(:qp_group_by_params_for,
          group_fields: [build(:qp_select_field_params_for, alias: "repeated")],
          aggregate_fields: [
            build(:qp_select_field_params_for,
              alias: "repeated",
              expression:
                build(:expression_params_for,
                  shape: "function",
                  value: build(:ev_function)
                )
            )
          ]
        )

      %{
        "aggregate_fields" => [
          %{
            "expression" => %{
              "value" => %{
                "name" => function_name,
                "type" => function_type
              }
            }
          }
        ]
      } = params

      insert(:function, name: function_name, type: function_type, class: "aggregator")

      assert %{valid?: false} =
               changeset =
               QueryableProperties.changeset(%QueryableProperties{}, params, "group_by")

      %{errors: errors} = ChangesetJSON.error(%{changeset: changeset})

      assert %{group_by: %{fields: ["invalid duplicated alias"]}} = errors
    end
  end

  describe "Select QueryableProperties tests" do
    test "test invalid duplicated alias" do
      params =
        string_params_for(:qp_select_params_for,
          fields: [
            build(:qp_select_field_params_for, alias: "repeated"),
            build(:qp_select_field_params_for, alias: "repeated")
          ]
        )

      assert %{valid?: false} =
               changeset = QueryableProperties.changeset(%QueryableProperties{}, params, "select")

      %{errors: errors} = ChangesetJSON.error(%{changeset: changeset})

      assert %{select: %{fields: ["invalid duplicated alias"]}} = errors
    end
  end
end
