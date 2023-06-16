defmodule TdQxWeb.DataSetControllerTest do
  use TdQxWeb.ConnCase

  @invalid_data_set_attrs %{name: nil, data_structure_id: nil}

  setup :verify_on_exit!

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all data_sets", %{conn: conn} do
      [%{id: ds_id1}, %{id: ds_id2}, %{id: ds_id3}] =
        datasets =
        ["dataset1", "dataset2", "dataset3"]
        |> Enum.map(&insert(:data_set, name: &1))

      [%{id: data_struct_id1}, %{id: data_struct_id2}, %{id: data_struct_id3}] =
        data_structures =
        datasets
        |> Enum.map(&build(:data_structure, id: &1.data_structure_id))

      cluster_handler_expect({:ok, data_structures})

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
               |> get(Routes.data_set_path(conn, :index))
               |> json_response(200)
    end
  end

  describe "show" do
    test "show data_sets with valid data", %{conn: conn} do
      %{id: ds_id} = data_structure = build(:data_structure)
      %{id: id} = insert(:data_set, data_structure_id: ds_id)

      cluster_handler_expect({:ok, data_structure})

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
               |> get(Routes.data_set_path(conn, :show, id))
               |> json_response(:ok)
    end

    test "show data_sets with invalid data", %{conn: conn} do
      %{id: id} = insert(:data_set)

      assert_error_sent(:not_found, fn ->
        get(conn, Routes.data_set_path(conn, :show, id + 1))
      end)
    end
  end

  describe "create data_set" do
    test "create data_set when data is valid", %{conn: conn} do
      %{id: data_structure_id} = data_structure = build(:data_structure)

      dataset_attrs = %{
        name: "foo",
        data_structure_id: data_structure_id
      }

      cluster_handler_expect({:ok, data_structure}, 2)

      assert %{"data" => %{"id" => id}} =
               conn
               |> post(Routes.data_set_path(conn, :create, data_set: dataset_attrs))
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
               |> get(Routes.data_set_path(conn, :show, id))
               |> json_response(200)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      assert conn
             |> post(Routes.data_set_path(conn, :create, data_set: @invalid_data_set_attrs))
             |> json_response(:unprocessable_entity)
    end
  end

  describe "update data_set" do
    test "update data_set when data is valid", %{conn: conn} do
      %{id: id, data_structure_id: ds_id} = data_set = insert(:data_set)
      data_structure = build(:data_structure, id: ds_id)

      update_attr = %{
        name: "foo"
      }

      cluster_handler_expect({:ok, data_structure}, 2)

      assert conn
             |> put(Routes.data_set_path(conn, :update, data_set, data_set: update_attr))
             |> json_response(:ok)

      assert %{
               "data" => %{
                 "id" => ^id,
                 "data_structure_id" => ^ds_id,
                 "name" => "foo"
               }
             } =
               conn
               |> get(Routes.data_set_path(conn, :show, data_set))
               |> json_response(:ok)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      data_set = insert(:data_set)

      assert conn
             |> put(
               Routes.data_set_path(conn, :update, data_set, data_set: @invalid_data_set_attrs)
             )
             |> json_response(:unprocessable_entity)
    end
  end

  describe "delete data_set" do
    test "deletes chosen data_set", %{conn: conn} do
      data_set = insert(:data_set)

      assert conn
             |> delete(Routes.data_set_path(conn, :delete, data_set))
             |> response(:no_content)

      assert_error_sent(:not_found, fn ->
        get(conn, Routes.data_set_path(conn, :show, data_set))
      end)
    end

    test "deletes invalid data_set renders error", %{conn: conn} do
      %{id: id} = insert(:data_set)

      assert_error_sent(:not_found, fn ->
        delete(conn, Routes.data_set_path(conn, :delete, id + 1))
      end)
    end
  end

  defp cluster_handler_expect(expected, times \\ 1),
    do: expect(MockClusterHandler, :call, times, fn _, _, _, _ -> expected end)
end
