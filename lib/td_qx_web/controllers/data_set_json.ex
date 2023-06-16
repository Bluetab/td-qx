defmodule TdQxWeb.DataSetJSON do
  alias TdQx.DataSets.DataSet
  alias TdQxWeb.DataStructureJson

  @doc """
  Renders a list of data_sets.
  """
  def index(%{data_sets: data_sets}) do
    %{data: for(data_set <- data_sets, do: data(data_set))}
  end

  @doc """
  Renders a single data_set.
  """
  def show(%{data_set: data_set}) do
    %{data: data(data_set)}
  end

  defp data(%DataSet{} = data_set) do
    data_set
    |> Map.take([
      :id,
      :name,
      :data_structure_id,
      :data_structure
    ])
    |> add_data_structure()
  end

  defp add_data_structure(data_set) do
    %{data_structure: data_structure} = DataStructureJson.show(data_set)
    Map.put(data_set, :data_structure, data_structure)
  end
end
