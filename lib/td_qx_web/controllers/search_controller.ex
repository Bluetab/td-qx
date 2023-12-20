defmodule TdQxWeb.SearchController do
  use TdQxWeb, :controller

  alias TdCore.Search
  alias TdCore.Search.Permissions, as: SearchPermissions
  alias TdCore.Search.Query
  alias TdQx.Executions.Actions
  alias TdQx.Permissions
  alias TdQx.QualityControls

  action_fallback(TdQxWeb.FallbackController)

  # @index_worker Application.compile_env(:td_qx, :dq_index_worker)
  @default_page 0
  @default_size 20

  def create(conn, %{} = params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(QualityControls, :search, claims) do
      results = do_search(params, claims)

      conn
      |> Actions.put_actions(claims)
      |> render(:show, results: results)
    end
  end

  def filters(conn, %{} = params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(QualityControls, :search, claims) do
      {query, aggs} = build_query(params, claims)

      search = %{query: query, aggs: aggs, size: 0}

      case Search.get_filters(search, :quality_controls) do
        {:ok, response} -> render(conn, :show, results: response)
        {:error, _error} -> render(conn, :show, results: %{})
      end
    end
  end

  def reindex(conn, _params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(QualityControl, :reindex, claims) do
      Search.IndexWorker.reindex(:quality_controls, :all)
      send_resp(conn, :accepted, "")
    end
  end

  defp build_query(params, claims) do
    permissions_filter =
      SearchPermissions.filter_for_permissions(["view_quality_controls"], claims)

    aggs = Search.ElasticDocumentProtocol.aggregations(%QualityControls.QualityControl{})
    query = Query.build_query(permissions_filter, params, aggs)
    {query, aggs}
  end

  defp do_search(%{"must" => must = %{"executable" => ["true"]}} = params, claims) do
    params
    |> Map.put("must", Map.delete(must, "executable"))
    |> do_search(claims)
    |> Enum.filter(&Permissions.is_visible_by_permissions(&1, claims))
  end

  defp do_search(%{} = params, claims) do
    page = Map.get(params, "page", @default_page)
    size = Map.get(params, "size", @default_size)

    sort = Map.get(params, "sort") || %{}

    {query, _} = build_query(params, claims)

    search = %{from: page * size, size: size, query: query, sort: sort}

    case Search.search(search, :quality_controls) do
      {:ok, %{total: _total, results: results}} -> results
      {:error, error} -> error
    end
  end
end
