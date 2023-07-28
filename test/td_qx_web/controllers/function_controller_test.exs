defmodule TdQxWeb.FunctionControllerTest do
  use TdQxWeb.ConnCase

  alias TdQx.Functions.Function

  @create_attrs %{
    description: "some description",
    expression: %{
      shape: "constant",
      value: %{
        type: "string",
        value: "some expression"
      }
    },
    name: "some name",
    params: [%{id: 1, name: "param1", type: "string"}],
    type: "string"
  }
  @update_attrs %{
    description: "some updated description",
    expression: %{
      shape: "constant",
      value: %{
        type: "string",
        value: "some updated expression"
      }
    },
    name: "some updated name",
    params: [%{id: 2, name: "param2", type: "boolean"}],
    type: "boolean"
  }
  @invalid_attrs %{description: nil, expression: nil, name: nil, params: nil, type: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag authentication: [role: "admin"]
    test "lists all functions", %{conn: conn} do
      conn = get(conn, ~p"/api/functions")
      assert json_response(conn, 200)["data"] == []
    end

    @tag authentication: [role: "user"]
    test "returns forbidden when requested by non admin user", %{conn: conn} do
      ["func1", "func2", "func3"] |> Enum.map(&insert(:function, name: &1))

      assert conn
             |> get(~p"/api/functions")
             |> json_response(:forbidden)
    end
  end

  describe "show" do
    @tag authentication: [role: "admin"]
    test "show function with valid data", %{conn: conn} do
      %{id: id} = insert(:function)

      assert %{
               "data" => %{
                 "id" => ^id
               }
             } =
               conn
               |> get(~p"/api/functions/#{id}")
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "show function with invalid data", %{conn: conn} do
      %{id: id} = insert(:function)
      invalid_id = id + 1

      assert_error_sent(:not_found, fn ->
        get(conn, ~p"/api/functions/#{invalid_id}")
      end)
    end

    @tag authentication: [role: "user"]
    test "returns forbidden when requested by non admin user", %{conn: conn} do
      %{id: id} = insert(:function)

      assert conn
             |> get(~p"/api/functions/#{id}")
             |> json_response(:forbidden)
    end
  end

  describe "create function" do
    @tag authentication: [role: "admin"]
    test "renders function when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/functions", function: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/functions/#{id}")

      assert %{
               "id" => ^id,
               "description" => "some description",
               "expression" => %{
                 "shape" => "constant",
                 "value" => %{"type" => "string", "value" => "some expression"}
               },
               "name" => "some name",
               "params" => [%{"description" => nil, "name" => "param1", "type" => "string"}],
               "type" => "string"
             } = json_response(conn, 200)["data"]
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/functions", function: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    @tag authentication: [role: "user"]
    test "returns forbidden when requested by non admin user", %{conn: conn} do
      assert conn
             |> post(~p"/api/functions", function: @create_attrs)
             |> json_response(:forbidden)
    end
  end

  describe "update function" do
    setup [:create_function]

    @tag authentication: [role: "admin"]
    test "renders function when data is valid", %{
      conn: conn,
      function: %Function{id: id} = function
    } do
      conn = put(conn, ~p"/api/functions/#{function}", function: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/api/functions/#{id}")

      assert %{
               "id" => ^id,
               "description" => "some updated description",
               "expression" => %{
                 "shape" => "constant",
                 "value" => %{"type" => "string", "value" => "some updated expression"}
               },
               "name" => "some updated name",
               "params" => [%{"description" => nil, "name" => "param2", "type" => "boolean"}],
               "type" => "boolean"
             } = json_response(conn, 200)["data"]
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn, function: function} do
      conn = put(conn, ~p"/api/functions/#{function}", function: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    @tag authentication: [role: "user"]
    test "returns forbidden when requested by non admin user", %{conn: conn, function: function} do
      update_attr = %{
        name: "foo"
      }

      assert conn
             |> put(~p"/api/functions/#{function}", function: update_attr)
             |> json_response(:forbidden)
    end
  end

  describe "delete function" do
    setup [:create_function]

    @tag authentication: [role: "admin"]
    test "deletes chosen function", %{conn: conn, function: function} do
      conn = delete(conn, ~p"/api/functions/#{function}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/functions/#{function}")
      end
    end

    @tag authentication: [role: "user"]
    test "returns forbidden when requested by non admin user", %{conn: conn, function: function} do
      assert conn
             |> delete(~p"/api/functions/#{function}")
             |> response(:forbidden)
    end

    @tag authentication: [role: "admin"]
    test "deletes invalid function renders error", %{conn: conn, function: %{id: id}} do
      invalid_id = id + 1

      assert_error_sent(:not_found, fn ->
        delete(conn, ~p"/api/functions/#{invalid_id}")
      end)
    end
  end

  defp create_function(_) do
    %{function: insert(:function)}
  end
end
