defmodule TdQxWeb.DataViewControllerTest do
  use TdQxWeb.ConnCase

  import QueryableHelpers

  alias TdCluster.TestHelpers.TdDdMock

  @invalid_data_view_attrs %{name: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag authentication: [role: "admin"]
    test "lists all data_views", %{conn: conn} do
      %{id: id, name: name} = insert(:data_view)

      assert %{"data" => [%{"id" => ^id, "name" => ^name}]} =
               conn
               |> get(~p"/api/data_views")
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "returns forbidden when requested by non admin user", %{conn: conn} do
      assert conn
             |> get(~p"/api/data_views")
             |> json_response(:forbidden)
    end

    @tag authentication: [role: "admin"]
    test "lists data_views with embedded resource", %{conn: conn} do
      reference_dataset =
        %{
          id: ref_ds_id,
          name: ref_ds_name,
          headers: [header1, header2]
        } = build(:reference_dataset)

      %{
        id: id,
        name: name
      } =
        insert_data_view_with_from_resource(
          build(:resource,
            id: ref_ds_id,
            type: "reference_dataset"
          )
        )

      TdDdMock.get_reference_dataset(&Mox.expect/4, ref_ds_id, {:ok, reference_dataset})

      assert %{
               "data" => [
                 %{
                   "id" => ^id,
                   "name" => ^name,
                   "queryables" => [
                     %{
                       "properties" => %{
                         "resource" => %{
                           "type" => "reference_dataset",
                           "embedded" => %{
                             "id" => ^ref_ds_id,
                             "name" => ^ref_ds_name,
                             "fields" => [
                               %{
                                 "name" => ^header1,
                                 "parent_name" => ^ref_ds_name,
                                 "type" => "string"
                               },
                               %{
                                 "name" => ^header2,
                                 "parent_name" => ^ref_ds_name,
                                 "type" => "string"
                               }
                             ]
                           }
                         }
                       }
                     }
                   ]
                 }
               ]
             } =
               conn
               |> get(~p"/api/data_views")
               |> json_response(:ok)
    end
  end

  describe "show" do
    @tag authentication: [role: "admin"]
    test "show data_views with valid data", %{conn: conn} do
      %{id: id} = insert(:data_view)

      assert %{"data" => %{"id" => ^id}} =
               conn
               |> get(~p"/api/data_views/#{id}")
               |> json_response(:ok)
    end

    test "returns unauthenticated when no credentials are passed", %{conn: conn} do
      %{id: id} = insert(:data_view)

      assert conn
             |> get(~p"/api/data_views/#{id}")
             |> response(:unauthorized)
    end

    @tag authentication: [role: "user"]
    test "returns forbidden when requested by non admin user", %{conn: conn} do
      %{id: id} = insert(:data_view)

      assert conn
             |> get(~p"/api/data_views/#{id}")
             |> json_response(:forbidden)
    end

    @tag authentication: [role: "admin"]
    test "show data_views with invalid data", %{conn: conn} do
      %{id: id} = insert(:data_view)
      invalid_id = id + 1

      assert_error_sent(:not_found, fn ->
        get(conn, ~p"/api/data_views/#{invalid_id}")
      end)
    end
  end

  describe "create data_view" do
    @tag authentication: [role: "admin"]
    test "create data_view when data is valid", %{conn: conn, claims: %{user_id: user_id}} do
      queryable_attrs = string_params_for(:data_view_queryable_params_for)

      select_attrs =
        string_params_for(:data_view_queryable,
          alias: nil,
          id: nil,
          type: "select",
          properties: params_for(:qp_select_params_for)
        )

      data_view_attrs = %{
        name: "some name",
        description: "some description",
        queryables: [queryable_attrs],
        select: select_attrs
      }

      assert %{"data" => %{"id" => id}} =
               conn
               |> post(~p"/api/data_views", data_view: data_view_attrs)
               |> json_response(:created)

      assert %{
               "data" => %{
                 "id" => ^id,
                 "name" => "some name",
                 "description" => "some description",
                 "created_by_id" => ^user_id,
                 "queryables" => [queryable],
                 "select" => select
               }
             } =
               conn
               |> get(~p"/api/data_views/#{id}")
               |> json_response(:ok)

      assert queryable == queryable_attrs
      assert select == select_attrs
    end

    @tag authentication: [role: "user"]
    test "returns forbidden when requested by non admin user", %{conn: conn} do
      data_view_attrs = %{name: "foo"}

      assert conn
             |> post(~p"/api/data_views", data_view: data_view_attrs)
             |> json_response(:forbidden)
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn} do
      assert conn
             |> post(~p"/api/data_views", data_view: @invalid_data_view_attrs)
             |> json_response(:unprocessable_entity)
    end
  end

  describe "update data_view" do
    @tag authentication: [role: "admin"]
    test "update data_view when data is valid", %{conn: conn} do
      %{id: id} = data_view = insert(:data_view)

      update_attr = %{name: "updated name", description: "updated description"}

      assert conn
             |> put(~p"/api/data_views/#{data_view}", data_view: update_attr)
             |> json_response(:ok)

      assert %{
               "data" => %{
                 "id" => ^id,
                 "name" => "updated name",
                 "description" => "updated description"
               }
             } =
               conn
               |> get(~p"/api/data_views/#{data_view}")
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "returns forbidden when requested by non admin user", %{conn: conn} do
      data_view = insert(:data_view)

      update_attr = %{
        name: "foo"
      }

      assert conn
             |> put(~p"/api/data_views/#{data_view}", data_view: update_attr)
             |> json_response(:forbidden)
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn} do
      data_view = insert(:data_view)

      assert conn
             |> put(~p"/api/data_views/#{data_view}", data_view: @invalid_data_view_attrs)
             |> json_response(:unprocessable_entity)
    end
  end

  describe "delete data_view" do
    @tag authentication: [role: "admin"]
    test "deletes chosen data_view", %{conn: conn} do
      data_view = insert(:data_view)

      assert conn
             |> delete(~p"/api/data_views/#{data_view}")
             |> response(:no_content)

      assert_error_sent(:not_found, fn ->
        get(conn, ~p"/api/data_views/#{data_view}")
      end)
    end

    @tag authentication: [role: "user"]
    test "returns forbidden when requested by non admin user", %{conn: conn} do
      data_view = insert(:data_view)

      assert conn
             |> delete(~p"/api/data_views/#{data_view}")
             |> response(:forbidden)
    end

    @tag authentication: [role: "admin"]
    test "deletes invalid data_view renders error", %{conn: conn} do
      %{id: id} = insert(:data_view)
      invalid_id = id + 1

      assert_error_sent(:not_found, fn ->
        delete(conn, ~p"/api/data_views/#{invalid_id}")
      end)
    end
  end
end
