defmodule TdQxWeb.ExecutionGroupsControllerTest do
  use TdQxWeb.ConnCase

  import Mox

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  setup :verify_on_exit!

  describe "index" do
    @tag authentication: [role: "admin"]
    test "Admin get all execution groups", %{conn: conn} do
      Enum.each(1..2, fn _ -> create_execution(3) end)

      %{"data" => response_executions} =
        conn
        |> get(~p"/api/quality_controls/execution_groups")
        |> json_response(:ok)

      assert length(response_executions) == 2
    end

    @tag authentication: [
           role: "user",
           permissions: [
             :execute_quality_controls
           ]
         ]
    test "User with permissions get all execution groups", %{conn: conn} do
      Enum.each(1..2, fn _ -> create_execution(3) end)

      %{"data" => response_executions} =
        conn
        |> get(~p"/api/quality_controls/execution_groups")
        |> json_response(:ok)

      assert length(response_executions) == 2
    end

    @tag authentication: [
           role: "user"
         ]
    test "User without permissions get all execution groups", %{conn: conn} do
      Enum.each(1..2, fn _ -> create_execution(3) end)

      assert %{"errors" => %{"detail" => "Forbidden"}} ==
               conn
               |> get(~p"/api/quality_controls/execution_groups")
               |> json_response(:forbidden)
    end
  end

  describe "show" do
    @tag authentication: [role: "admin"]
    test "Admin get a execution group with their related executions", %{conn: conn} do
      %{id: execution_group_id, executions: executions} = create_execution_group(3)

      %{
        "data" => %{
          "id" => response_execution_group_id,
          "executions" => response_executions
        }
      } =
        conn
        |> get(~p"/api/quality_controls/execution_groups/#{execution_group_id}")
        |> json_response(:ok)

      executions_id = Enum.map(executions, fn m -> Map.get(m, :id) end)

      response_executions_id = Enum.map(response_executions, fn m -> m["id"] end)

      assert response_execution_group_id == execution_group_id
      assert length(response_executions) == 3
      assert response_executions_id === executions_id
    end

    @tag authentication: [
           role: "user",
           permissions: [
             :execute_quality_controls
           ]
         ]
    test "User with permissions get a execution group with their related executions", %{
      conn: conn
    } do
      %{id: execution_group_id, executions: executions} = create_execution_group(3)

      %{
        "data" => %{
          "id" => response_execution_group_id,
          "executions" => response_executions
        }
      } =
        conn
        |> get(~p"/api/quality_controls/execution_groups/#{execution_group_id}")
        |> json_response(:ok)

      executions_id = Enum.map(executions, fn m -> Map.get(m, :id) end)

      response_executions_id = Enum.map(response_executions, fn m -> m["id"] end)

      assert response_execution_group_id == execution_group_id
      assert length(response_executions) == 3
      assert response_executions_id === executions_id
    end

    @tag authentication: [
           role: "user"
         ]
    test "User without permissions get a execution group with their related executions", %{
      conn: conn
    } do
      %{id: execution_group_id} = create_execution_group(3)

      assert %{"errors" => %{"detail" => "Forbidden"}} ==
               conn
               |> get(~p"/api/quality_controls/execution_groups/#{execution_group_id}")
               |> json_response(:forbidden)
    end
  end

  describe "create execution_groups" do
    @tag authentication: [role: "admin"]
    test "Admin create execution group", %{conn: conn} do
      quality_controls =
        Enum.map(1..3, fn _ ->
          create_quality_control()
          |> Map.merge(%{template: %{foo: "bar"}})
        end)

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/quality_controls/_search", _, _ ->
        SearchHelpers.hits_response(quality_controls)
      end)

      creation_params = %{
        "df_content" => %{"scheduled" => "Si"},
        "query" => ""
      }

      conn = post(conn, ~p"/api/quality_controls/execution_groups", creation_params)

      assert %{"executions" => [_, _, _]} = json_response(conn, 201)["data"]
    end

    @tag authentication: [
           role: "user",
           permissions: [
             :execute_quality_controls
           ]
         ]
    test "User with permissions create execution group", %{conn: conn} do
      quality_controls =
        Enum.map(1..3, fn _ ->
          create_quality_control()
          |> Map.merge(%{template: %{foo: "bar"}})
        end)

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/quality_controls/_search", _, _ ->
        SearchHelpers.hits_response(quality_controls)
      end)

      creation_params = %{
        "df_content" => %{"scheduled" => "Si"},
        "query" => ""
      }

      conn = post(conn, ~p"/api/quality_controls/execution_groups", creation_params)

      assert %{"executions" => [_, _, _]} = json_response(conn, 201)["data"]
    end

    @tag authentication: [
           role: "user"
         ]
    test "User without permissions create execution group", %{conn: conn} do
      Enum.map(1..3, fn _ ->
        create_quality_control()
        |> Map.merge(%{template: %{foo: "bar"}})
      end)

      creation_params = %{
        "df_content" => %{"scheduled" => "Si"},
        "query" => ""
      }

      assert %{"errors" => %{"detail" => "Forbidden"}} ==
               conn
               |> post(~p"/api/quality_controls/execution_groups", creation_params)
               |> json_response(:forbidden)
    end
  end

  defp create_execution_group(max) do
    executions = create_execution(max)

    insert(:execution_groups, executions: executions)
  end

  defp create_execution(max) do
    %{id: eg_id} = insert(:execution_groups)

    Enum.map(1..max, fn _id ->
      %{id: qc_id} = create_quality_control()

      insert(:execution, %{execution_group_id: eg_id, quality_control_id: qc_id})
    end)
  end

  defp create_quality_control do
    quality_control = insert(:quality_control)

    quality_control_version =
      insert(:quality_control_version,
        status: "published",
        quality_control: quality_control
      )

    Map.merge(quality_control, %{
      latest_version: quality_control_version,
      published_version: quality_control_version
    })
  end
end
