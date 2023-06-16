defmodule TdQx.DataSets do
  @moduledoc """
  The DataSets context.
  """

  import Ecto.Query, warn: false

  alias TdCluster.ClusterHandler
  alias TdQx.DataSets.DataSet
  alias TdQx.Repo

  @doc """
  Returns the list of data_sets.

  ## Examples

      iex> list_data_sets()
      [%DataSet{}, ...]

  """
  def list_data_sets(opts \\ []) do
    DataSet
    |> Repo.all()
    |> enrich(opts)
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
    |> enrich(opts)
  end

  @doc """
  Creates a data_set.

  ## Examples

      iex> create_data_set(%{field: value})
      {:ok, %DataSet{}}

      iex> create_data_set(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_data_set(attrs, opts \\ []) do
    %DataSet{}
    |> DataSet.changeset(attrs)
    |> Repo.insert()
    |> enrich(opts)
  end

  @doc """
  Updates a data_set.

  ## Examples

      iex> update_data_set(data_set, %{field: new_value})
      {:ok, %DataSet{}}

      iex> update_data_set(data_set, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_data_set(%DataSet{} = data_set, attrs, opts \\ []) do
    data_set
    |> DataSet.changeset(attrs)
    |> Repo.update()
    |> enrich(opts)
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

  defp enrich(:data_structure, datasets) when is_list(datasets) do
    data_structures_ids = Enum.map(datasets, &Map.get(&1, :data_structure_id))

    {:ok, data_structures} =
      ClusterHandler.call(:dd, TdDd.DataStructures, :get_data_structures, [data_structures_ids])

    Enum.map(datasets, fn data_set ->
      data_structure_id = data_set.data_structure_id
      data_structure = Enum.find(data_structures, &(&1.id === data_structure_id))
      Map.put(data_set, :data_structure, data_structure)
    end)
  end

  defp enrich(:data_structure, dataset) do
    {:ok, data_structure} =
      ClusterHandler.call(:dd, TdDd.DataStructures, :get_data_structure!, [
        dataset.data_structure_id
      ])

    Map.put(dataset, :data_structure, data_structure)
  end

  defp enrich({:ok, dataset}, enrich: fields), do: {:ok, enrich(dataset, enrich: fields)}

  defp enrich({:error, dataset} = error, _), do: error

  defp enrich(dataset, enrich: fields), do: Enum.reduce(fields, dataset, &enrich(&1, &2))

  defp enrich(dataset, _), do: dataset
end
