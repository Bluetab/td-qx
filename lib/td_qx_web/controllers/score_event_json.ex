defmodule TdQxWeb.ScoreEventJSON do
  @doc """
  Renders a single score_event.
  """

  alias TdQx.Scores.ScoreEvent

  def show(%{score_event: score_event}) do
    %{data: data(score_event)}
  end

  def render_many([%ScoreEvent{} | _] = events), do: for(event <- events, do: data(event))
  def render_many([]), do: []
  def render_many(_), do: nil

  defp data(%ScoreEvent{} = score_event) do
    %{
      id: score_event.id,
      type: score_event.type,
      message: score_event.message,
      score_id: score_event.score_id,
      inserted_at: score_event.inserted_at
    }
  end
end
