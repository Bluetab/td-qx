defmodule TdQx.Search do
  @moduledoc """
  Search for Quality Controls.
  """

  alias TdCore.Search
  alias TdCore.Search.ElasticDocumentProtocol
  alias TdCore.Search.Permissions
  alias TdCore.Search.Query
  alias TdQx.QualityControls.QualityControl
  alias TdQx.Scores.ScoreGroup

  @default_page 0
  @default_size 20
  @score_group_size 1_000

  def search(%{"scroll_id" => _} = params, _claims) do
    params
    |> Map.take(["scroll", "scroll_id"])
    |> do_search(%{})
  end

  def search(params, claims) do
    page = Map.get(params, "page", @default_page)
    size = Map.get(params, "size", @default_size)

    sort = Map.get(params, "sort", ["_score", "name.raw"])

    {query, _} = build_query(params, claims)

    do_search(%{from: page * size, size: size, query: query, sort: sort}, params)
  end

  def search_score_groups(params, claims) do
    page = Map.get(params, "page", @default_page)
    size = Map.get(params, "size", @score_group_size)

    sort = Map.get(params, "sort", ["_score"])

    {query, _} = build_query(params, claims, :score_groups)
    search = %{from: page * size, size: size, query: query, sort: sort}
    do_search(search, params, :score_groups)
  end

  def filters(%{} = params, claims, index \\ :quality_controls) do
    {query, aggs} = build_query(params, claims, index)

    Search.get_filters(%{query: query, aggs: aggs, size: 0}, index)
  end

  defp do_search(search, params, index \\ :quality_controls)

  defp do_search(%{"scroll_id" => _scroll_id} = search, _params, _index) do
    search
    |> Search.scroll()
    |> transform_response
  end

  defp do_search(search, %{"scroll" => scroll}, index) do
    search
    |> Search.search(index, params: %{"scroll" => scroll})
    |> transform_response
  end

  defp do_search(search, _params, index) do
    search
    |> Search.search(index)
    |> transform_response
  end

  defp build_query(params, claims, index \\ :quality_controls)

  defp build_query(%{"must" => %{"for_execution" => [true]}} = params, claims, :quality_controls) do
    permissions_filter =
      Permissions.filter_for_permissions(
        ["view_quality_controls", "execute_quality_controls"],
        claims
      )

    params =
      Map.update!(
        params,
        "must",
        &(&1
          |> Map.drop(["for_execution"])
          |> Map.put("active", [true]))
      )

    query_data = %{aggs: aggs} = fetch_query_data()
    opts = Keyword.new(query_data)

    query = Query.build_query(permissions_filter, params, opts)
    {query, aggs}
  end

  defp build_query(params, claims, :quality_controls) do
    permissions_filter = Permissions.filter_for_permissions(["view_quality_controls"], claims)

    query_data = %{aggs: aggs} = fetch_query_data()
    opts = Keyword.new(query_data)

    query = Query.build_query(permissions_filter, params, opts)

    {query, aggs}
  end

  defp build_query(params, claims, :score_groups) do
    permissions_filter = Permissions.filter_for_permissions([], claims)

    query_data = %{aggs: aggs} = fetch_query_data(%ScoreGroup{})
    opts = Keyword.new(query_data)

    query = Query.build_query(permissions_filter, params, opts)

    {query, aggs}
  end

  defp transform_response({:ok, response}), do: transform_response(response)

  defp transform_response({:error, response}), do: %{results: response, total: 0}

  defp transform_response(%{results: results, total: total, scroll_id: scroll_id}) do
    new_results = Enum.map(results, &Map.get(&1, "_source"))

    %{results: new_results, total: total, scroll_id: scroll_id}
  end

  defp transform_response(%{results: results, total: total}) do
    new_results = Enum.map(results, &Map.get(&1, "_source"))
    %{results: new_results, total: total}
  end

  defp fetch_query_data(schema \\ %QualityControl{})

  defp fetch_query_data(schema) do
    schema
    |> ElasticDocumentProtocol.query_data()
    |> with_search_clauses()
  end

  defp with_search_clauses(%{fields: fields} = query_data) do
    multi_match_bool_prefix = %{
      multi_match: %{
        type: "bool_prefix",
        fields: fields,
        lenient: true,
        fuzziness: "AUTO"
      }
    }

    query_data
    |> Map.take([:aggs])
    |> Map.put(:clauses, [multi_match_bool_prefix])
  end
end
