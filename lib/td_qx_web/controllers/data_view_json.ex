defmodule TdQxWeb.DataViewJSON do
  alias TdQx.DataViews.DataView
  alias TdQxWeb.QueryableJSON

  @doc """
  Renders a list of data_views.
  """
  def index(%{data_views: data_views}) do
    %{data: for(data_view <- data_views, do: data(data_view))}
  end

  @doc """
  Renders a single data_view.
  """
  def show(%{data_view: data_view}) do
    %{data: data(data_view)}
  end

  defp data(%DataView{} = data_view) do
    %{
      id: data_view.id,
      name: data_view.name,
      description: data_view.description,
      created_by_id: data_view.created_by_id,
      source_id: data_view.source_id,
      queryables: QueryableJSON.embed_many(data_view),
      select: QueryableJSON.embed_one(data_view.select)
    }
  end
end

defmodule TdQxWeb.QueryableJSON do
  alias TdQx.DataViews.DataView
  alias TdQx.DataViews.Queryable
  alias TdQxWeb.QueryablePropertiesJSON

  def embed_many(%DataView{queryables: [%Queryable{} | _] = queryables}),
    do: for(queryable <- queryables, do: data(queryable))

  def embed_many(_), do: []

  def embed_one(%Queryable{} = queryable), do: data(queryable)

  def embed_one(_), do: nil

  def data(%Queryable{} = queryable) do
    %{
      type: queryable.type,
      properties: QueryablePropertiesJSON.embed_one(queryable)
    }
    |> with_id(queryable)
    |> with_alias(queryable)
  end

  defp with_alias(json, %{alias: alias_value}) when is_binary(alias_value),
    do: Map.put(json, :alias, alias_value)

  defp with_alias(json, _), do: json

  defp with_id(json, %{id: id}) when is_integer(id),
    do: Map.put(json, :id, id)

  defp with_id(json, _), do: json
end
