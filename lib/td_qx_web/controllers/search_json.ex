defmodule TdQxWeb.SearchJSON do
  @moduledoc """
  Provides JSON view for Search
  """

  @doc """
  Renders search results
  """

  alias TdQx.Scores.ScoreGroup

  @score_group_fields [
    :id,
    :status_summary,
    :inserted_at,
    :df_type,
    :dynamic_content,
    :created_by
  ]

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
        Map.put(acc, :data, render_many(results))

      {:scroll_id, scroll_id}, acc ->
        Map.put(acc, :scroll_id, scroll_id)

      _, acc ->
        acc
    end)
  end

  def render_many([%ScoreGroup{} | _] = score_groups),
    do: for(score_group <- score_groups, do: data(score_group))

  def render_many([%{} | _] = data), do: data

  def render_many(%{} = data), do: data

  def render_many([]), do: []
  def render_many(_), do: nil

  defp data(%ScoreGroup{} = score_group) do
    Map.take(score_group, @score_group_fields)
  end
end
