defmodule TdQxWeb.SearchController do
  use TdQxWeb, :controller

  alias TdCore.Search
  alias TdCore.Search.Permissions, as: SearchPermissions
  alias TdCore.Search.Query
  alias TdQx.Executions.Actions
  alias TdQx.Permissions
  alias TdQx.QualityControls
  alias TdQx.Search.Indexer

  action_fallback(TdQxWeb.FallbackController)

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
      Indexer.reindex(:all)
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

    %{from: page * size, size: size, query: query, sort: sort}
    |> Search.search(:quality_controls)
    |> transform_response
  end

  defp transform_response({:ok, response}), do: transform_response(response)
  defp transform_response({:error, _} = response), do: response
  defp transform_response(%{results: results}), do: Enum.map(results, &Map.get(&1, "_source"))
end
