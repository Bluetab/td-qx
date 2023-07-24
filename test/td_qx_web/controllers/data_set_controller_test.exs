defmodule TdQxWeb.DataSetControllerTest do
  use TdQxWeb.ConnCase

  @invalid_data_set_attrs %{name: nil, data_structure_id: nil}

  setup :verify_on_exit!

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag authentication: [role: "admin"]
    test "lists all data_sets", %{conn: conn} do
      [%{id: ds_id1}, %{id: ds_id2}, %{id: ds_id3}] =
        data_sets =
        ["data_set1", "data_set2", "data_set3"]
        |> Enum.map(&insert(:data_set, name: &1))

      [%{id: data_struct_id1}, %{id: data_struct_id2}, %{id: data_struct_id3}] =
        data_structures =
        data_sets
        |> Enum.map(&build(:data_structure, id: &1.data_structure_id))

      cluster_handler_expect(:call, {:ok, data_structures})

      assert %{
               "data" => [
                 %{
                   "id" => ^ds_id1,
                   "data_structure" => %{"id" => ^data_struct_id1}
                 },
                 %{
                   "id" => ^ds_id2,
                   "data_structure" => %{"id" => ^data_struct_id2}
                 },
                 %{
                   "id" => ^ds_id3,
                   "data_structure" => %{"id" => ^data_struct_id3}
                 }
               ]
             } =
               conn
               |> get(~p"/api/data_sets")
               |> json_response(200)
    end

    @tag authentication: [role: "user"]
    test "returns forbidden when requested by non admin user", %{conn: conn} do
      ["data_set1", "data_set2", "data_set3"] |> Enum.map(&insert(:data_set, name: &1))

      assert conn
             |> get(~p"/api/data_sets")
             |> json_response(:forbidden)
    end
  end

  describe "show" do
    @tag authentication: [role: "admin"]
    test "show data_sets with valid data", %{conn: conn} do
      %{id: ds_id} = data_structure = build(:data_structure)
      %{id: id} = insert(:data_set, data_structure_id: ds_id)

      cluster_handler_expect(:call, {:ok, data_structure})

      assert %{
               "data" => %{
                 "id" => ^id,
                 "data_structure_id" => ^ds_id,
                 "data_structure" => %{
                   "id" => ^ds_id
                 }
               }
             } =
               conn
               |> get(~p"/api/data_sets/#{id}")
               |> json_response(:ok)
    end

    test "returns unauthenticated when no credentials are passed", %{conn: conn} do
      %{id: id} = insert(:data_set)

      assert conn
             |> get(~p"/api/data_sets/#{id}")
             |> response(:unauthorized)
    end

    @tag authentication: [role: "user"]
    test "returns forbidden when requested by non admin user", %{conn: conn} do
      %{id: id} = insert(:data_set)

      assert conn
             |> get(~p"/api/data_sets/#{id}")
             |> json_response(:forbidden)
    end

    @tag authentication: [role: "admin"]
    test "show data_sets with invalid data", %{conn: conn} do
      %{id: id} = insert(:data_set)
      invalid_id = id + 1

      assert_error_sent(:not_found, fn ->
        get(conn, ~p"/api/data_sets/#{invalid_id}")
      end)
    end
  end

  describe "create data_set" do
    @tag authentication: [role: "admin"]
    test "create data_set when data is valid", %{conn: conn} do
      %{id: data_structure_id} = data_structure = build(:data_structure)

      data_set_attrs = %{
        name: "foo",
        data_structure_id: data_structure_id
      }

      cluster_handler_expect(:call, {:ok, data_structure}, 2)

      assert %{"data" => %{"id" => id}} =
               conn
               |> post(~p"/api/data_sets", data_set: data_set_attrs)
               |> json_response(201)

      assert %{
               "data" => %{
                 "id" => ^id,
                 "data_structure_id" => ^data_structure_id,
                 "name" => "foo",
                 "data_structure" => %{
                   "id" => ^data_structure_id
                 }
               }
             } =
               conn
               |> get(~p"/api/data_sets/#{id}")
               |> json_response(200)
    end

    @tag authentication: [role: "user"]
    test "returns forbidden when requested by non admin user", %{conn: conn} do
      %{id: data_structure_id} = build(:data_structure)

      data_set_attrs = %{
        name: "foo",
        data_structure_id: data_structure_id
      }

      assert conn
             |> post(~p"/api/data_sets", data_set: data_set_attrs)
             |> json_response(:forbidden)
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn} do
      assert conn
             |> post(~p"/api/data_sets", data_set: @invalid_data_set_attrs)
             |> json_response(:unprocessable_entity)
    end
  end

  describe "update data_set" do
    @tag authentication: [role: "admin"]
    test "update data_set when data is valid", %{conn: conn} do
      %{id: id, data_structure_id: ds_id} = data_set = insert(:data_set)
      data_structure = build(:data_structure, id: ds_id)

      update_attr = %{
        name: "foo"
      }

      cluster_handler_expect(:call, {:ok, data_structure}, 2)

      assert conn
             |> put(~p"/api/data_sets/#{data_set}", data_set: update_attr)
             |> json_response(:ok)

      assert %{
               "data" => %{
                 "id" => ^id,
                 "data_structure_id" => ^ds_id,
                 "name" => "foo"
               }
             } =
               conn
               |> get(~p"/api/data_sets/#{data_set}")
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "returns forbidden when requested by non admin user", %{conn: conn} do
      data_set = insert(:data_set)

      update_attr = %{
        name: "foo"
      }

      assert conn
             |> put(~p"/api/data_sets/#{data_set}", data_set: update_attr)
             |> json_response(:forbidden)
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn} do
      data_set = insert(:data_set)

      assert conn
             |> put(~p"/api/data_sets/#{data_set}", data_set: @invalid_data_set_attrs)
             |> json_response(:unprocessable_entity)
    end
  end

  describe "delete data_set" do
    @tag authentication: [role: "admin"]
    test "deletes chosen data_set", %{conn: conn} do
      data_set = insert(:data_set)

      assert conn
             |> delete(~p"/api/data_sets/#{data_set}")
             |> response(:no_content)

      assert_error_sent(:not_found, fn ->
        get(conn, ~p"/api/data_sets/#{data_set}")
      end)
    end

    @tag authentication: [role: "user"]
    test "returns forbidden when requested by non admin user", %{conn: conn} do
      data_set = insert(:data_set)

      assert conn
             |> delete(~p"/api/data_sets/#{data_set}")
             |> response(:forbidden)
    end

    @tag authentication: [role: "admin"]
    test "deletes invalid data_set renders error", %{conn: conn} do
      %{id: id} = insert(:data_set)
      invalid_id = id + 1

      assert_error_sent(:not_found, fn ->
        delete(conn, ~p"/api/data_sets/#{invalid_id}")
      end)
    end
  end
end
