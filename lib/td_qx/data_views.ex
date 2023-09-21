defmodule TdQx.DataViews do
  @moduledoc """
  The DataViews context.
  """

  import Ecto.Query, warn: false

  alias TdCluster.Cluster.TdDd
  alias TdQx.DataViews.DataView
  alias TdQx.Expressions.Expression
  alias TdQx.Repo

  require Logger

  defdelegate authorize(action, user, params), to: __MODULE__.Policy

  @doc """
  Returns the list of data_views.

  ## Examples

      iex> list_data_views()
      [%DataView{}, ...]

  """
  def list_data_views(opts \\ []) do
    DataView
    |> Repo.all()
    |> maybe_enrich(opts[:enrich])
  end

  @doc """
  Gets a single data_view.

  Raises `Ecto.NoResultsError` if the Data set does not exist.

  ## Examples

      iex> get_data_view!(123)
      %DataView{}

      iex> get_data_view!(456)
      ** (Ecto.NoResultsError)

  """
  def get_data_view!(id, opts \\ []) do
    DataView
    |> Repo.get!(id)
    |> maybe_enrich(opts[:enrich])
  end

  @doc """
  Gets a single data_view.

  Raises `Ecto.NoResultsError` if the Data set does not exist.

  ## Examples

      iex> get_data_view(123)
      %DataView{}

      iex> get_data_view(456)
      nil

  """
  def get_data_view(id, opts \\ []) do
    DataView
    |> Repo.get(id)
    |> maybe_enrich(opts[:enrich])
  end

  @doc """
  Creates a data_view.

  ## Examples

      iex> create_data_view(%{field: value})
      {:ok, %DataView{}}

      iex> create_data_view(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_data_view(attrs) do
    %DataView{}
    |> DataView.changeset(attrs)
    |> Repo.insert()
    |> maybe_enrich()
  end

  @doc """
  Updates a data_view.

  ## Examples

      iex> update_data_view(data_view, %{field: new_value})
      {:ok, %DataView{}}

      iex> update_data_view(data_view, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_data_view(%DataView{} = data_view, attrs) do
    data_view
    |> DataView.changeset(attrs)
    |> Repo.update()
    |> maybe_enrich()
  end

  @doc """
  Deletes a data_view.

  ## Examples

      iex> delete_data_view(data_view)
      {:ok, %DataView{}}

      iex> delete_data_view(data_view)
      {:error, %Ecto.Changeset{}}

  """
  def delete_data_view(%DataView{} = data_view) do
    Repo.delete(data_view)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking data_view changes.

  ## Examples

      iex> change_data_view(data_view)
      %Ecto.Changeset{data: %DataView{}}

  """
  def change_data_view(%DataView{} = data_view, attrs \\ %{}) do
    DataView.changeset(data_view, attrs)
  end

  defp maybe_enrich(data_view), do: maybe_enrich(data_view, false)

  defp maybe_enrich(data_view, true), do: do_enrich(data_view)
  defp maybe_enrich(data_view, _), do: data_view

  defp do_enrich({:ok, data_view}), do: {:ok, do_enrich(data_view)}

  defp do_enrich({:error, _dataset} = error), do: error

  defp do_enrich(data_views) when is_list(data_views), do: Enum.map(data_views, &do_enrich/1)

  defp do_enrich(%DataView{queryables: [_ | _] = queryables} = data_view) do
    queryables = Enum.map(queryables, &enrich_queryable/1)

    Map.put(data_view, :queryables, queryables)
  end

  defp do_enrich(data_view), do: data_view

  defp enrich_queryable(
         %{type: "from", properties: %{from: %{resource: resource} = from} = properties} =
           queryable
       ),
       do: %{
         queryable
         | properties: %{properties | from: %{from | resource: enrich_resource(resource)}}
       }

  defp enrich_queryable(
         %{type: "join", properties: %{join: %{resource: resource} = join} = properties} =
           queryable
       ),
       do: %{
         queryable
         | properties: %{properties | join: %{join | resource: enrich_resource(resource)}}
       }

  defp enrich_queryable(queryable), do: queryable

  defp enrich_resource(%{type: "reference_dataset", id: id} = resource) do
    case TdDd.get_reference_dataset(id) do
      {:ok, %{id: id, name: name, headers: headers}} ->
        fields =
          Enum.with_index(headers, fn field_name, id ->
            %{
              id: id,
              name: field_name,
              type: "string",
              parent_name: name
            }
          end)

        Map.put(resource, :embedded, %{
          id: id,
          name: name,
          fields: fields
        })

      _ ->
        Logger.warning("Failed to enrich %ReferenceDataset{id: #{id}} from cluster")
        resource
    end
  end

  defp enrich_resource(%{type: "data_structure", id: id} = resource) do
    case TdDd.get_latest_structure_version(id) do
      {:ok, %{name: name, data_fields: data_fields}} ->
        fields =
          Enum.map(data_fields, fn %{data_structure_id: id, name: field_name, metadata: metadata} ->
            %{
              id: id,
              name: field_name,
              type: Map.get(metadata, "data_type_class", "string"),
              parent_name: name
            }
          end)

        Map.put(resource, :embedded, %{
          id: id,
          name: name,
          fields: fields
        })

      _ ->
        Logger.warning("Failed to enrich %ReferenceDataset{id: #{id}} from cluster")
        resource
    end
  end

  defp enrich_resource(%{type: "data_view", id: id} = resource) do
    case get_data_view(id) do
      %{name: name, select: select} ->
        fields =
          select
          |> Map.get(:properties)
          |> Map.get(:select)
          |> Map.get(:fields)
          |> Enum.map(fn %{id: id, alias: field_alias, expression: expression} ->
            %{
              id: id,
              name: field_alias,
              type: Expression.type(expression),
              parent_name: name
            }
          end)

        Map.put(resource, :embedded, %{
          id: id,
          name: name,
          fields: fields
        })

      _ ->
        resource
    end
  end

  defp enrich_resource(resource), do: resource
end
