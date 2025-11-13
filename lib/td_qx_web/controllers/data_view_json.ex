defmodule TdQxWeb.DataViewJSON do
  alias TdQx.DataViews.DataView
  alias TdQx.DataViews.Queryable

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
      mode: data_view.mode,
      description: data_view.description,
      created_by_id: data_view.created_by_id,
      source_id: data_view.source_id,
      queryables: Queryable.to_json(data_view.queryables),
      select: Queryable.to_json(data_view.select)
    }
  end
end
