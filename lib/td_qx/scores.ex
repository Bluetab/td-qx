defmodule TdQx.Scores do
  @moduledoc """
  The Scores context.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias TdQx.Repo
  alias TdQx.Scores.Score
  alias TdQx.Scores.ScoreEvent
  alias TdQx.Scores.ScoreGroup

  defdelegate authorize(action, user, params), to: __MODULE__.Policy

  defp score_groups_query(opts) do
    opts
    |> Enum.reduce(ScoreGroup, fn
      {:id, id}, q -> where(q, [eg], eg.id == ^id)
      {:created_by, user_id}, q -> where(q, [eg], eg.created_by == ^user_id)
      {:preload, preload}, q -> score_group_preload_query(preload, q)
    end)
  end

  defp score_group_preload_query(preload, query) when is_list(preload) do
    Enum.reduce(preload, query, fn
      {:scores, preload}, q ->
        preload_query = score_preload_query(preload)
        preload(q, scores: ^preload_query)

      preload, q ->
        preload(q, [^preload])
    end)
  end

  defp score_group_preload_query(preload, query) when is_atom(preload),
    do: score_group_preload_query([preload], query)

  def list_score_groups(opts \\ []) do
    opts
    |> score_groups_query()
    |> Repo.all()
  end

  def aggregate_status_summary(score_groups) do
    Enum.map(score_groups, fn %{scores: scores} = group ->
      status_summary =
        Enum.reduce(scores, %{}, fn %{status: status}, acc ->
          count = Map.get(acc, status, 0)
          Map.put(acc, status, count + 1)
        end)

      %{group | scores: nil, status_summary: status_summary}
    end)
  end

  def get_score_group(score_group_id, opts \\ []) do
    opts
    |> Keyword.put(:id, score_group_id)
    |> score_groups_query
    |> Repo.one()
  end

  def create_score_group([], _), do: {:error, :unprocessable_entity}

  def create_score_group(quality_control_version_ids, params) do
    changeset = ScoreGroup.changeset(%ScoreGroup{}, params)

    multi =
      Multi.new()
      |> Multi.insert(:score_group, changeset)

    quality_control_version_ids
    |> Enum.reduce(multi, fn qcv_id, multi ->
      Multi.insert(
        multi,
        String.to_atom("score_#{qcv_id}"),
        &multi_insert_score(&1, qcv_id)
      )
    end)
    |> Repo.transaction()
  end

  defp multi_insert_score(
         %{score_group: %{id: group_id}},
         quality_control_version_id
       ) do
    Score.create_grouped_changeset(%{
      group_id: group_id,
      quality_control_version_id: quality_control_version_id
    })
  end

  defp scores_query(opts) do
    base_query = from(s in Score, as: :score)

    opts
    |> Enum.reduce(base_query, fn
      {:id, id}, q ->
        where(q, [s], s.id == ^id)

      {:status, status}, q ->
        q
        |> score_with_status_query()
        |> where([latest_event: le], le.type == ^status)

      {:sources, source_ids}, q ->
        q
        |> join(:inner, [score: s], qcv in assoc(s, :quality_control_version), as: :qcv_sources)
        |> join(:inner, [qcv_sources: qcv], qc in assoc(qcv, :quality_control), as: :qc_source)
        |> where([qc_source: qc], qc.source_id in ^source_ids)

      {:quality_control_id, quality_control_id}, q ->
        q
        |> join(:inner, [score: s], qcv in assoc(s, :quality_control_version), as: :qcv)
        |> where([qcv: qcv], qcv.quality_control_id == ^quality_control_id)

      {:preload, preload}, q ->
        score_preload_query(preload, q)
    end)
  end

  def list_scores(opts \\ []) do
    opts
    |> scores_query
    |> Repo.all()
  end

  def get_score(score_id, opts \\ []) do
    opts
    |> Keyword.put(:id, score_id)
    |> scores_query
    |> Repo.one()
  end

  defp score_preload_query(preload, query \\ Score)

  defp score_preload_query(preload, query) when is_atom(preload),
    do: score_preload_query([preload], query)

  defp score_preload_query(preload, query) when is_list(preload) do
    Enum.reduce(preload, query, fn
      :status, q -> score_with_status_query(q)
      preload, q -> preload(q, [^preload])
    end)
  end

  defp score_with_status_query(query) do
    latest_events =
      from(e in ScoreEvent,
        where: e.type not in ["INFO", "WARNING"],
        select: %{
          score_id: e.score_id,
          type: e.type,
          rn:
            row_number()
            |> over(partition_by: e.score_id, order_by: [desc: e.inserted_at])
        }
      )
      |> subquery()
      |> where([e], e.rn == 1)

    query
    |> join(:inner, [s], le in ^latest_events, on: s.id == le.score_id, as: :latest_event)
    |> select_merge([latest_event: le], %{status: le.type})
  end

  def update_scores_quality_control_properties(opts \\ []) do
    query =
      opts
      |> Keyword.put(:preload, [])
      |> scores_query()

    from(s in query,
      join: qcv in assoc(s, :quality_control_version),
      update: [
        set: [
          quality_control_status: qcv.status,
          score_type:
            fragment(
              "CASE
                WHEN ? IN ('deviation', 'percentage') THEN 'ratio'
                WHEN ? IN ('error_count') THEN 'error_count'
                ELSE NULL
              END",
              qcv.control_mode,
              qcv.control_mode
            )
        ]
      ]
    )
    |> Repo.update_all([])
  end

  def updated_succeeded_score(score, params) do
    score
    |> Score.suceedded_changeset(params)
    |> Repo.update()
    |> case do
      {:ok, score} ->
        create_score_event(%{
          score_id: score.id,
          type: "SUCCEEDED"
        })

        {:ok, score}

      error ->
        error
    end
  end

  def updated_failed_score(score, params) do
    score
    |> Score.failed_changeset(params)
    |> Repo.update()
    |> case do
      {:ok, score} ->
        create_score_event(%{
          score_id: score.id,
          type: "FAILED"
        })

        {:ok, score}

      error ->
        error
    end
  end

  def delete_score(%Score{} = score) do
    Repo.delete(score)
  end

  def insert_event_for_scores(scores, event_params) do
    utc_now = DateTime.utc_now()

    events =
      scores
      |> Enum.map(fn %{id: id} ->
        Map.merge(
          event_params,
          %{
            score_id: id,
            inserted_at: utc_now,
            updated_at: utc_now
          }
        )
      end)

    Repo.insert_all(ScoreEvent, events, returning: true)
  end

  def create_score_event(attrs \\ %{}) do
    %ScoreEvent{}
    |> ScoreEvent.changeset(attrs)
    |> Repo.insert()
  end
end
