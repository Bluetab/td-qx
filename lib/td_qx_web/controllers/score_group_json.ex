defmodule TdQxWeb.ScoreGroupJSON do
  alias TdQx.Scores.ScoreGroup

  alias TdQxWeb.ScoreJSON

  @doc """
  Renders a list of score_groups.
  """
  def index(%{score_groups: score_groups}) do
    %{
      data: for(%ScoreGroup{} = score_group <- score_groups, do: data(score_group))
    }
  end

  def show(%{score_group: score_group}) do
    %{data: data(score_group)}
  end

  defp data(%ScoreGroup{} = score_group) do
    %{
      id: score_group.id,
      df_type: score_group.df_type,
      dynamic_content: score_group.dynamic_content,
      created_by: score_group.created_by,
      inserted_at: score_group.inserted_at,
      updated_at: score_group.updated_at,
      scores: ScoreJSON.render_many(score_group.scores),
      status_summary: score_group.status_summary
    }
  end
end
