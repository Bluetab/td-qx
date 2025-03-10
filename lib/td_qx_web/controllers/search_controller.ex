defmodule TdQxWeb.SearchController do
  use TdQxWeb, :controller

  alias TdCache.UserCache
  alias TdQx.QualityControls
  alias TdQx.Scores
  alias TdQx.Scores.ScoreGroup
  alias TdQx.Search
  alias TdQx.Search.Indexer

  action_fallback(TdQxWeb.FallbackController)

  def create(conn, %{} = params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(QualityControls, :search, claims) do
      %{results: results, total: total} = search_data = Search.search(params, claims)

      conn
      |> put_resp_header("x-total-count", "#{total}")
      |> put_actions(claims)
      |> render(:show,
        results: results,
        scroll_id: Map.get(search_data, :scroll_id)
      )
    end
  end

  def create_score_groups(conn, params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Scores, :search, claims, ScoreGroup) do
      %{results: results, total: total} =
        params
        |> maybe_add_created_by(claims)
        |> Search.search_score_groups(claims)

      score_groups_by_id =
        Enum.into(results, %{}, fn %{"id" => id, "created_by" => created_by} ->
          {id, created_by}
        end)

      score_groups_with_summary =
        results
        |> Enum.map(fn %{"id" => id} -> id end)
        |> then(&Scores.list_score_groups(ids: &1, preload: [scores: :status]))
        |> Scores.aggregate_status_summary()
        |> Enum.map(fn %{id: id} = result ->
          Map.put(result, :created_by, Map.get(score_groups_by_id, id))
        end)

      conn
      |> put_resp_header("x-total-count", "#{total}")
      |> put_actions(claims)
      |> render(:show, results: score_groups_with_summary)
    end
  end

  def filters(conn, %{} = params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(QualityControls, :search, claims) do
      case Search.filters(params, claims) do
        {:ok, response} -> render(conn, :show, results: response)
        {:error, _error} -> render(conn, :show, results: %{})
      end
    end
  end

  def score_group_filters(conn, %{} = params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Scores, :search, claims, ScoreGroup) do
      case Search.filters(params, claims, :score_groups) do
        {:ok, response} -> render(conn, :show, results: response)
        {:error, _error} -> render(conn, :show, results: %{})
      end
    end
  end

  def quality_controls_reindex(conn, _params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(QualityControls, :reindex, claims) do
      Indexer.reindex(:all)
      send_resp(conn, :accepted, "")
    end
  end

  def score_groups_reindex(conn, _params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Scores, :reindex, claims) do
      Indexer.reindex(:all, :score_groups)
      send_resp(conn, :accepted, "")
    end
  end

  def put_actions(conn, claims) do
    [:execute]
    |> Enum.filter(&Bodyguard.permit?(TdQx.QualityControls, &1, claims, %{}))
    |> Map.new(fn
      action ->
        {action, %{method: "POST"}}
    end)
    |> then(&assign(conn, :actions, &1))
  end

  defp maybe_add_created_by(%{"created_by" => "me"} = params, %{user_id: user_id}) do
    {:ok, %{user_name: user_name}} = UserCache.get(user_id)

    params
    |> Map.get("must", %{})
    |> Map.put("created_by", [user_name])
    |> then(&Map.put(params, "must", &1))
    |> Map.delete("created_by")
  end

  defp maybe_add_created_by(params, _claims), do: params
end
