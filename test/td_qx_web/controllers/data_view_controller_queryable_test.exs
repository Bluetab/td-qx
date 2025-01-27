defmodule TdQxWeb.DataViewControllerQueryableTest do
  use TdQxWeb.ConnCase

  import QueryableHelpers
  alias TdCluster.TestHelpers.TdDdMock

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "create data_view with queryable properties" do
    for type <- ~w|from join select where group_by| do
      @tag authentication: [role: "admin"]
      @tag type: type
      test "create data_view with queryable properties of type '#{type}'", %{
        conn: conn,
        type: type
      } do
        properties = valid_properties_for(type)

        data_view_attrs = %{
          name: "data_view",
          source_id: 10,
          queryables: [
            %{id: 1, type: type, alias: "queryable_alias", properties: properties}
          ],
          select:
            string_params_for(:data_view_queryable,
              type: "select",
              properties: string_params_for(:qp_select_params_for)
            )
        }

        assert %{"data" => %{"id" => id}} =
                 conn
                 |> post(~p"/api/data_views", data_view: data_view_attrs)
                 |> json_response(:created)

        assert %{
                 "data" => %{
                   "id" => ^id,
                   "queryables" => [
                     %{
                       "id" => 1,
                       "type" => ^type,
                       "alias" => "queryable_alias",
                       "properties" => result_properties
                     }
                   ]
                 }
               } =
                 conn
                 |> get(~p"/api/data_views/#{id}")
                 |> json_response(:ok)

        assert properties == drop_properties_embedded(result_properties)
      end
    end

    @error_by_type %{
      "from" => %{
        "from" => %{"resource" => ["can't be blank"]}
      },
      "group_by" => %{
        "group_by" => %{
          "group_fields" => ["can't be blank"]
        }
      },
      "join" => %{
        "join" => %{"resource" => ["can't be blank"], "clauses" => ["can't be blank"]}
      },
      "select" => %{"select" => %{"fields" => ["can't be blank"]}},
      "where" => %{"where" => %{"clauses" => ["can't be blank"]}}
    }

    for {type, expected_error} <- @error_by_type do
      @tag authentication: [role: "admin"]
      @tag type: type, expected_error: expected_error
      test "create data_view with invalid '#{type}' queryable properties", %{
        conn: conn,
        type: type,
        expected_error: expected_error
      } do
        data_view_attrs = %{
          name: "data_view",
          queryables: [%{id: 1, type: type, properties: %{}}]
        }

        assert %{"errors" => errors} =
                 conn
                 |> post(~p"/api/data_views", data_view: data_view_attrs)
                 |> json_response(:unprocessable_entity)

        assert %{"queryables" => [%{"properties" => result_error}]} = errors
        assert expected_error == result_error
      end
    end
  end

  describe "update data_view with queryable properties" do
    @tag authentication: [role: "admin"]
    test "update data_view with valid data updates queryables", %{conn: conn} do
      data_view =
        insert(:data_view,
          queryables: [
            build(:data_view_queryable,
              type: "from",
              properties: build(:queryable_properties, from: build(:qp_from))
            )
          ]
        )

      properties = string_params_for(:qp_join_params_for)

      update_attr = %{
        queryables: [
          params_for(:data_view_queryable,
            type: "join",
            properties: properties
          )
        ]
      }

      assert conn
             |> put(~p"/api/data_views/#{data_view}", data_view: update_attr)
             |> json_response(:ok)

      assert %{
               "data" => %{
                 "queryables" => [
                   %{
                     "type" => "join",
                     "properties" => result_properties
                   }
                 ]
               }
             } =
               conn
               |> get(~p"/api/data_views/#{data_view}")
               |> json_response(:ok)

      assert properties == drop_properties_embedded(result_properties)
    end

    @tag authentication: [role: "admin"]
    test "update data_view with valid data updates queryables properties", %{conn: conn} do
      data_view =
        insert(:data_view,
          queryables: [
            build(:data_view_queryable,
              type: "from",
              properties:
                build(:queryable_properties,
                  from: build(:qp_from, resource: build(:resource, id: 1, type: "data_view"))
                )
            )
          ]
        )

      %{"resource" => properties_resource} =
        properties =
        string_params_for(:qp_from,
          resource: string_params_for(:resource, id: 2, type: "data_structure")
        )

      update_attr = %{
        queryables: [
          params_for(:data_view_queryable,
            type: "from",
            properties: properties
          )
        ]
      }

      TdDdMock.get_latest_structure_version(
        &Mox.expect/4,
        2,
        {:ok, %{data_structure_id: 2, name: "ds_name", data_fields: []}}
      )

      assert conn
             |> put(~p"/api/data_views/#{data_view}", data_view: update_attr)
             |> json_response(:ok)

      assert %{
               "data" => %{
                 "queryables" => [
                   %{"type" => "from", "properties" => result_properties}
                 ]
               }
             } =
               conn
               |> get(~p"/api/data_views/#{data_view}")
               |> json_response(:ok)

      assert %{
               "resource" =>
                 Map.put(properties_resource, "embedded", %{
                   "fields" => [],
                   "id" => 2,
                   "name" => "ds_name"
                 })
             } == result_properties
    end

    @tag authentication: [role: "admin"]
    test "update data_view with valid data updates queryables with other queryable", %{conn: conn} do
      data_view =
        insert(:data_view,
          queryables: [
            build(:data_view_queryable,
              type: "from",
              properties: build(:queryable_properties, from: build(:qp_from))
            )
          ]
        )

      from_properties = string_params_for(:qp_from)
      join_properties = string_params_for(:qp_join_params_for)

      update_attr = %{
        queryables: [
          params_for(:data_view_queryable,
            type: "from",
            properties: from_properties
          ),
          params_for(:data_view_queryable,
            type: "join",
            properties: join_properties
          )
        ]
      }

      assert conn
             |> put(~p"/api/data_views/#{data_view}", data_view: update_attr)
             |> json_response(:ok)

      assert %{
               "data" => %{
                 "queryables" => [
                   %{"type" => "from", "properties" => result_from_properties},
                   %{"type" => "join", "properties" => result_join_properties}
                 ]
               }
             } =
               conn
               |> get(~p"/api/data_views/#{data_view}")
               |> json_response(:ok)

      assert from_properties == drop_properties_embedded(result_from_properties)
      assert join_properties == drop_properties_embedded(result_join_properties)
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn} do
      data_view = insert(:data_view, queryables: [build(:data_view_queryable)])

      update_attr = %{
        queryables: [
          %{
            type: "from",
            properties: %{}
          }
        ]
      }

      assert %{"errors" => errors} =
               conn
               |> put(~p"/api/data_views/#{data_view}", data_view: update_attr)
               |> json_response(:unprocessable_entity)

      assert %{
               "queryables" => [
                 %{},
                 %{
                   "id" => ["can't be blank"],
                   "properties" => %{"from" => %{"resource" => ["can't be blank"]}}
                 }
               ]
             } = errors
    end
  end
end
