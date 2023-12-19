defmodule TdQxWeb.SearchJSON do
  @moduledoc """
  Provides JSON view for Search
  """

  @doc """
  Renders search results
  """
  def show(%{results: %Elasticsearch.Exception{}} = assigns) do
    assigns
    |> Map.put(:results, %{})
    |> reduce_response()
  end

  def show(%{} = assigns) do
    reduce_response(assigns)
  end

  defp reduce_response(%{} = assigns) do
    Enum.reduce(assigns, %{}, fn
      {:actions, actions}, acc ->
        Map.put(acc, :actions, actions)

      {:results, results}, acc ->
        Map.put(acc, :data, results)

      _, acc ->
        acc
    end)
  end
end
