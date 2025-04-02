defmodule TdQxWeb.ScoreGroupController do
  use TdQxWeb, :controller

  alias TdQx.Scores
  alias TdQx.Scores.ScoreGroup
  alias TdQx.Search

  action_fallback TdQxWeb.FallbackController

  def index(conn, %{"created_by" => "me"}) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Scores, :index, claims, ScoreGroup) do
      score_groups =
        [created_by: claims.user_id, preload: [scores: :status]]
        |> Scores.list_score_groups()
        |> Scores.aggregate_status_summary()

      render(conn, :index, score_groups: score_groups)
    end
  end

  def index(_conn, _), do: {:error, :unprocessable_entity}

  def show(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]

    with %ScoreGroup{} = score_group <-
           Scores.get_score_group(id,
             preload: [scores: [:status, quality_control_version: :quality_control]]
           ),
         :ok <- Bodyguard.permit(Scores, :show, claims, score_group) do
      render(conn, :show, score_group: score_group)
    end
  end

  def create(conn, %{"score_group" => score_group_params, "search" => search_params}) do
    %{user_id: user_id} = claims = conn.assigns[:current_resource]

    score_group_params = Map.put(score_group_params, "created_by", user_id)

    with :ok <- Bodyguard.permit(Scores, :create, claims, ScoreGroup),
         %{results: quality_controls} <- Search.search(search_params, claims),
         version_ids <- Enum.map(quality_controls, & &1["id"]),
         {:ok, %{score_group: %{id: id}}} <-
           Scores.create_score_group(version_ids, score_group_params) do
      score_group = Scores.get_score_group(id)

      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/score_groups/#{id}")
      |> render(:show, score_group: score_group)
    end
  end

  def create(conn, %{
        "score_group" => score_group_params,
        "ids" => quality_control_version_ids
      }) do
    %{user_id: user_id} = claims = conn.assigns[:current_resource]

    score_group_params = Map.put(score_group_params, "created_by", user_id)

    with :ok <- Bodyguard.permit(Scores, :create, claims, ScoreGroup),
         {:ok, %{score_group: %{id: id}}} <-
           Scores.create_score_group(quality_control_version_ids, score_group_params) do
      score_group = Scores.get_score_group(id)

      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/score_groups/#{id}")
      |> render(:show, score_group: score_group)
    end
  end
end
