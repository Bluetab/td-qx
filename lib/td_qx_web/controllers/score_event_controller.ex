defmodule TdQxWeb.ScoreEventController do
  use TdQxWeb, :controller

  alias TdQx.Scores
  alias TdQx.Scores.ScoreEvent

  action_fallback TdQxWeb.FallbackController

  def create(conn, %{"score_id" => score_id, "score_event" => event_params}) do
    claims = conn.assigns[:current_resource]

    params = Map.put(event_params, "score_id", score_id)

    with :ok <- Bodyguard.permit(Scores, :create, claims, ScoreEvent),
         {:ok, %{score_event: event}} <-
           Scores.create_score_event(params, user_id: claims.user_id) do
      conn
      |> put_status(:created)
      |> render(:show, score_event: event)
    end
  end
end
