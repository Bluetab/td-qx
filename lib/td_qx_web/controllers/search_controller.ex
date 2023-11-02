defmodule TdQxWeb.SearchController do
  use TdQxWeb, :controller

  alias TdCore.Search
  alias TdCore.Search.Permissions
  alias TdCore.Search.Query
  alias TdQx.QualityControls

  action_fallback(TdQxWeb.FallbackController)

  # @index_worker Application.compile_env(:td_qx, :dq_index_worker)
  @default_page 0
  @default_size 20

  def create(conn, %{} = params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(QualityControls, :search, claims) do
      page = Map.get(params, "page", @default_page)
      size = Map.get(params, "size", @default_size)

      sort = Map.get(params, "sort") || %{}

      {query, _} = build_query(params, claims)

      {:ok, %{total: _total, results: results}} =
        %{from: page * size, size: size, query: query, sort: sort}
        |> Search.search(:quality_controls)

      render(conn, :show, results: results)
    end
  end

  def filters(conn, %{} = params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(QualityControls, :search, claims) do
      {query, aggs} = build_query(params, claims)

      {:ok, response} =
        %{query: query, aggs: aggs, size: 0}
        |> Search.get_filters(:quality_controls)

      render(conn, :show, results: response)
    end
  end

  defp build_query(params, claims) do
    permissions_filter = Permissions.filter_for_permissions(["view_quality_controls"], claims)
    aggs = Search.ElasticDocumentProtocol.aggregations(%QualityControls.QualityControl{})
    query = Query.build_query(permissions_filter, params, aggs)
    {query, aggs}
  end

  def reindex(conn, _params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(QualityControl, :reindex, claims) do
      Search.IndexWorker.reindex(:quality_controls, :all)
      send_resp(conn, :accepted, "")
    end
  end
end
