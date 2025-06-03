defmodule TdQxWeb.ScoreJSON do
  alias TdQx.Scores.Score

  alias TdQx.QualityControls.QualityControlVersion
  alias TdQx.Scores.ScoreContent
  alias TdQx.Scores.ScoreEvent
  alias TdQxWeb.QualityControlVersionJSON
  alias TdQxWeb.ScoreEventJSON

  @doc """
  Renders a list of scores.
  """
  def index(%{search: %{scores: scores_with_pag, last_execution_result: last_execution_result}}) do
    %{scores: scores} = scores_with_pag

    %{
      data: %{
        scores: for(score <- scores, do: data(score)),
        last_execution_result: last_execution_result,
        current_page: scores_with_pag.current_page,
        total_count: scores_with_pag.total_count,
        total_pages: scores_with_pag.total_pages,
        page_size: scores_with_pag.page_size
      }
    }
  end

  def index(%{scores: scores}) do
    %{data: for(score <- scores, do: data(score))}
  end

  def fetch_pending(%{scores: scores, resources_lookup: resources_lookup}) do
    %{
      data: for(%Score{} = score <- scores, do: data_queries(score)),
      resources_lookup: resources_lookup
    }
  end

  def render_many([%Score{} | _] = scores), do: for(score <- scores, do: data(score))
  def render_many([]), do: []
  def render_many(_), do: nil

  @doc """
  Renders a single score.
  """
  def show(%{score: score}) do
    %{data: data(score)}
  end

  defp data_queries(%Score{
         id: id,
         quality_control_version: %{
           queries: queries
         }
       }) do
    %{
      id: id,
      queries: queries
    }
  end

  defp data(%Score{} = score) do
    %{
      id: score.id,
      quality_control_version_id: score.quality_control_version_id,
      execution_timestamp: score.execution_timestamp,
      details: score.details,
      score_type: score.score_type,
      quality_control_status: score.quality_control_status,
      status: score.status,
      score_content: ScoreContent.to_json(score.score_content),
      created_at: score.inserted_at
    }
    |> with_quality_control_version(score)
    |> with_events(score)
  end

  defp with_quality_control_version(json, %{
         quality_control_version: %QualityControlVersion{} = qcv
       }) do
    Map.put(json, :quality_control, QualityControlVersionJSON.render_one(qcv))
  end

  defp with_quality_control_version(json, _), do: json

  defp with_events(json, %{events: [%ScoreEvent{} | _] = events}) do
    Map.put(json, :events, ScoreEventJSON.render_many(events))
  end

  defp with_events(json, _), do: json
end
