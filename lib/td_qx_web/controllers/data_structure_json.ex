defmodule TdQxWeb.DataStructureJson do
  @moduledoc """
  Provides JSON view for DataStructures
  """

  @doc """
  Renders a list of data_strutures.
  """
  def index(%{data_structures: data_strutures}) do
    %{data: for(data_structure <- data_strutures, do: data(data_structure))}
  end

  @doc """
  Renders a single data_structure.
  """
  def show(%{data_structure: data_structure}) do
    %{data_structure: data(data_structure)}
  end

  defp data(%{} = data_structure) do
    data_structure
    |> Map.take([
      :id,
      :system_id
    ])
  end
end
