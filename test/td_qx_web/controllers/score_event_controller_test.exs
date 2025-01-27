defmodule TdQxWeb.ScoreEventControllerTest do
  use TdQxWeb.ConnCase

  alias TdQx.Scores

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  setup {Mox, :verify_on_exit!}

  describe "create - POST /api/scores/:score_id/events" do
    @tag authentication: [role: "service"]
    test "create score event with valid params", %{conn: conn} do
      %{id: score_id} = insert(:score)

      params = %{type: "STARTED"}

      assert %{"score_id" => ^score_id, "type" => "STARTED"} =
               conn
               |> post(~p"/api/scores/#{score_id}/events", score_event: params)
               |> json_response(201)
               |> Map.get("data")
    end

    @tag authentication: [role: "user"]
    test "user without permission cannot create event", %{conn: conn} do
      %{id: score_id} = insert(:score)

      params = %{type: "STARTED"}

      assert conn
             |> post(~p"/api/scores/#{score_id}/events", score_event: params)
             |> response(:forbidden)
    end

    @tag authentication: [role: "service"]
    test "fails with invalid type", %{conn: conn} do
      %{id: score_id} = insert(:score)

      params = %{type: "invalid_type"}

      assert %{"errors" => %{"type" => ["is invalid"]}} =
               conn
               |> post(~p"/api/scores/#{score_id}/events", score_event: params)
               |> json_response(:unprocessable_entity)
    end

    @tag authentication: [role: "service"]
    test "fails with invalid score", %{conn: conn} do
      invalid_score_id = 999

      params = %{type: "TIMEOUT"}

      assert %{"errors" => %{"score_id" => ["does not exist"]}} =
               conn
               |> post(~p"/api/scores/#{invalid_score_id}/events", score_event: params)
               |> json_response(:unprocessable_entity)
    end

    @tag authentication: [role: "service"]
    test "info and warning events does not change score status", %{conn: conn} do
      %{id: score_id} = score = insert(:score)

      insert(:score_event, type: "QUEUED", score: score)

      assert %{status: "QUEUED"} = Scores.get_score(score_id, preload: :status)

      status = "STARTED"

      assert conn
             |> post(~p"/api/scores/#{score_id}/events", score_event: %{type: status})
             |> json_response(201)

      assert %{status: "STARTED"} = Scores.get_score(score_id, preload: :status)

      status = "INFO"

      assert conn
             |> post(~p"/api/scores/#{score_id}/events", score_event: %{type: status})
             |> json_response(201)

      assert %{status: "STARTED"} = Scores.get_score(score_id, preload: :status)

      status = "WARNING"

      assert conn
             |> post(~p"/api/scores/#{score_id}/events", score_event: %{type: status})
             |> json_response(201)

      assert %{status: "STARTED"} = Scores.get_score(score_id, preload: :status)
    end
  end
end
