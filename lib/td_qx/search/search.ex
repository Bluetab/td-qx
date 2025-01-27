defmodule TdQx.Search do
  @moduledoc """
  Search for Quality Controls.
  """

  alias TdCore.Search
  alias TdCore.Search.ElasticDocumentProtocol
  alias TdCore.Search.Permissions
  alias TdCore.Search.Query
  alias TdQx.QualityControls.QualityControl

  @default_page 0
  @default_size 20

  def search(%{} = params, claims) do
    page = Map.get(params, "page", @default_page)
    size = Map.get(params, "size", @default_size)

    sort = Map.get(params, "sort") || %{}

    {query, _} = build_query(params, claims)

    %{from: page * size, size: size, query: query, sort: sort}
    |> Search.search(:quality_controls)
    |> transform_response
  end

  def filters(%{} = params, claims) do
    {query, aggs} = build_query(params, claims)

    Search.get_filters(%{query: query, aggs: aggs, size: 0}, :quality_controls)
  end

  defp build_query(%{"must" => %{"for_execution" => [true]}} = params, claims) do
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

  defp build_query(params, claims) do
    permissions_filter = Permissions.filter_for_permissions(["view_quality_controls"], claims)

    query_data = %{aggs: aggs} = fetch_query_data()
    opts = Keyword.new(query_data)

    query = Query.build_query(permissions_filter, params, opts)

    {query, aggs}
  end

  defp transform_response({:ok, response}), do: transform_response(response)
  defp transform_response({:error, _} = response), do: response

  defp transform_response(%{results: results, total: total}) do
    new_results = Enum.map(results, &Map.get(&1, "_source"))
    {new_results, total}
  end

  defp fetch_query_data do
    %QualityControl{}
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
