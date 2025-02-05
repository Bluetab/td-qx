defmodule TdQxWeb.SearchController do
  use TdQxWeb, :controller

  alias TdQx.QualityControls
  alias TdQx.Search
  alias TdQx.Search.Indexer

  action_fallback(TdQxWeb.FallbackController)

  def create(conn, %{} = params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(QualityControls, :search, claims) do
      {results, total} = Search.search(params, claims)

      conn
      |> put_resp_header("x-total-count", "#{total}")
      |> put_actions(claims)
      |> render(:show, results: results)
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

  def reindex(conn, _params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(QualityControl, :reindex, claims) do
      Indexer.reindex(:all)
      send_resp(conn, :accepted, "")
    end
  end

  def put_actions(conn, claims) do
    [:execute, :view]
    |> Enum.filter(&Bodyguard.permit?(TdQx.Scores, &1, claims, %{}))
    |> Map.new(fn
      action ->
        {action, %{method: "POST"}}
    end)
    |> then(&assign(conn, :actions, &1))
  end
end
