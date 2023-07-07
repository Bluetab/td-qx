defmodule TdQx.DataSets do
  @moduledoc """
  The DataSets context.
  """

  import Ecto.Query, warn: false

  alias TdCluster.ClusterHandler
  alias TdQx.DataSets.DataSet
  alias TdQx.Repo

  require Logger

  @doc """
  Returns the list of data_sets.

  ## Examples

      iex> list_data_sets()
      [%DataSet{}, ...]

  """
  def list_data_sets(opts \\ []) do
    DataSet
    |> Repo.all()
    |> maybe_enrich(opts[:enrich])
  end

  @doc """
  Gets a single data_set.

  Raises `Ecto.NoResultsError` if the Data set does not exist.

  ## Examples

      iex> get_data_set!(123)
      %DataSet{}

      iex> get_data_set!(456)
      ** (Ecto.NoResultsError)

  """
  def get_data_set!(id, opts \\ []) do
    DataSet
    |> Repo.get!(id)
    |> maybe_enrich(opts[:enrich])
  end

  @doc """
  Creates a data_set.

  ## Examples

      iex> create_data_set(%{field: value})
      {:ok, %DataSet{}}

      iex> create_data_set(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_data_set(attrs) do
    %DataSet{}
    |> DataSet.changeset(attrs)
    |> Repo.insert()
    |> maybe_enrich()
  end

  @doc """
  Updates a data_set.

  ## Examples

      iex> update_data_set(data_set, %{field: new_value})
      {:ok, %DataSet{}}

      iex> update_data_set(data_set, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_data_set(%DataSet{} = data_set, attrs) do
    data_set
    |> DataSet.changeset(attrs)
    |> Repo.update()
    |> maybe_enrich()
  end

  @doc """
  Deletes a data_set.

  ## Examples

      iex> delete_data_set(data_set)
      {:ok, %DataSet{}}

      iex> delete_data_set(data_set)
      {:error, %Ecto.Changeset{}}

  """
  def delete_data_set(%DataSet{} = data_set) do
    Repo.delete(data_set)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking data_set changes.

  ## Examples

      iex> change_data_set(data_set)
      %Ecto.Changeset{data: %DataSet{}}

  """
  def change_data_set(%DataSet{} = data_set, attrs \\ %{}) do
    DataSet.changeset(data_set, attrs)
  end

  defp maybe_enrich(data_set), do: maybe_enrich(data_set, true)

  defp maybe_enrich(data_set, true), do: do_enrich(data_set)
  defp maybe_enrich(data_set, _), do: data_set

  defp do_enrich({:ok, data_set}), do: {:ok, do_enrich(data_set)}

  defp do_enrich({:error, _dataset} = error), do: error

  defp do_enrich(data_sets) when is_list(data_sets) do
    data_structures_ids =
      data_sets
      |> Enum.map(&Map.get(&1, :data_structure_id))
      |> Enum.uniq()

    cluster_response =
      ClusterHandler.call(:dd, TdDd.DataStructures, :get_data_structures, [data_structures_ids])

    case cluster_response do
      {:ok, data_structures} ->
        data_structures_map =
          data_structures
          |> Enum.map(fn data_structure -> {data_structure.id, data_structure} end)
          |> Map.new()

        Enum.map(
          data_sets,
          &Map.put(&1, :data_structure, Map.get(data_structures_map, &1.data_structure_id))
        )

      _ ->
        Logger.warning("Failed to enrich DataSet from cluster")
        data_sets
    end
  end

  defp do_enrich(data_set) do
    case ClusterHandler.call(:dd, TdDd.DataStructures, :get_data_structure!, [
           data_set.data_structure_id
         ]) do
      {:ok, data_structure} ->
        Map.put(data_set, :data_structure, data_structure)

      _ ->
        Logger.warning("Failed to enrich DataSet from cluster")
        data_set
    end
  end
end
