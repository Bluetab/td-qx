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
  alias TdQx.Search.Indexer

  defdelegate authorize(action, user, params), to: __MODULE__.Policy

  def score_groups_query(opts) do
    Enum.reduce(opts, ScoreGroup, fn
      {:id, id}, q ->
        where(q, [eg], eg.id == ^id)

      {:ids, ids}, q ->
        where(q, [eg], eg.id in ^ids)

      {:created_by, user_id}, q ->
        where(q, [eg], eg.created_by == ^user_id)

      {:preload, preload}, q ->
        score_group_preload_query(preload, q)

      _other, q ->
        q
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

    multi = Multi.insert(Multi.new(), :score_group, changeset)

    quality_control_version_ids
    |> Enum.reduce(multi, fn qcv_id, multi ->
      Multi.insert(
        multi,
        String.to_atom("score_#{qcv_id}"),
        &multi_insert_score(&1, qcv_id)
      )
    end)
    |> Repo.transaction()
    |> on_upsert()
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

  defp on_upsert({:ok, %{score_group: %{id: group_id}} = multi_results} = res) do
    version_ids =
      multi_results
      |> Map.delete(:score_group)
      |> Enum.map(fn {_score_key, %Score{quality_control_version_id: quality_control_version_id}} ->
        quality_control_version_id
      end)
      |> Enum.uniq()

    Indexer.reindex(ids: version_ids)
    Indexer.reindex([id: group_id], :score_groups)
    res
  end

  defp on_upsert(res), do: res

  def latest_score_subquery(opts \\ []) do
    opts
    |> scores_query()
    |> where([_s, le], le.type in ["FAILED", "SUCCEEDED"])
    |> order_by(desc: :execution_timestamp)
    |> limit(1)
  end

  defp scores_query(opts) do
    base_query = from(s in Score, as: :score)

    opts
    |> Enum.reduce(base_query, fn
      {:id, id}, q ->
        where(q, [s], s.id == ^id)

      {:group_ids, group_ids}, q ->
        where(q, [s], s.group_id in ^group_ids)

      {:status, status}, q ->
        q
        |> score_with_status_query()
        |> where([latest_event: le], le.type == ^status)

      {:sources, source_ids}, q ->
        q
        |> ensure_join_qcv()
        |> ensure_join_qc()
        |> where([qc: qc], qc.source_id in ^source_ids)

      {:quality_control_id, quality_control_id}, q ->
        q
        |> ensure_join_qcv()
        |> where([qcv: qcv], qcv.quality_control_id == ^quality_control_id)

      {:preload, preload}, q ->
        score_preload_query(preload, q)

      {:parent_quality_control_version, parent_alias}, q ->
        where(q, [s], s.quality_control_version_id == parent_as(^parent_alias).id)
    end)
  end

  # Helper for ensuring a named binding exists, with a cleaner syntax
  defp ensure_join(query, binding_name, {parent_binding, assoc_name}) do
    if has_named_binding?(query, binding_name) do
      query
    else
      join(query, :inner, [{^parent_binding, p}], a in assoc(p, ^assoc_name), as: ^binding_name)
    end
  end

  # Simple wrappers for common join patterns
  defp ensure_join_qcv(query), do: ensure_join(query, :qcv, {:score, :quality_control_version})
  defp ensure_join_qc(query), do: ensure_join(query, :qc, {:qcv, :quality_control})

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
                WHEN ? IN ('count') THEN 'count'
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
        create_score_event(
          %{
            score_id: score.id,
            type: "SUCCEEDED",
            message: Map.get(params, "message")
          },
          reindex: false
        )

        {:ok, score}

      error ->
        error
    end
    |> tap(&on_upserted_score/1)
  end

  def updated_failed_score(score, params) do
    score
    |> Score.failed_changeset(params)
    |> Repo.update()
    |> case do
      {:ok, score} ->
        create_score_event(
          %{
            score_id: score.id,
            type: "FAILED",
            message: Map.get(params, "message")
          },
          reindex: false
        )

        {:ok, score}

      error ->
        error
    end
    |> tap(&on_upserted_score/1)
  end

  def delete_score(%Score{} = score) do
    score
    |> Repo.delete()
    |> tap(&on_upserted_score/1)
  end

  def insert_event_for_scores(scores, event_params) do
    utc_now = DateTime.utc_now()

    events =
      Enum.map(scores, fn %{id: id} ->
        Map.merge(
          event_params,
          %{
            score_id: id,
            inserted_at: utc_now,
            updated_at: utc_now
          }
        )
      end)

    ScoreEvent
    |> Repo.insert_all(events, returning: true)
    |> tap(&on_events_insert/1)
  end

  def create_score_event(attrs \\ %{}, opts \\ []) do
    reindex = Keyword.get(opts, :reindex, true)

    %ScoreEvent{}
    |> ScoreEvent.changeset(attrs)
    |> Repo.insert()
    |> tap(&on_event_insert(&1, reindex))
  end

  defp on_events_insert({_n, events}) do
    version_ids =
      events
      |> Enum.map(&Repo.preload(&1, :score))
      |> Enum.map(fn %ScoreEvent{
                       score: %Score{quality_control_version_id: quality_control_version_id}
                     } ->
        quality_control_version_id
      end)
      |> Enum.uniq()

    Indexer.reindex(ids: version_ids)
  end

  defp on_event_insert({:ok, %ScoreEvent{score: %Score{} = score}}, true) do
    Indexer.reindex(ids: score.quality_control_version_id)
  end

  defp on_event_insert({:ok, %ScoreEvent{} = score_event}, true) do
    score =
      score_event
      |> Repo.preload(:score)
      |> Map.get(:score)

    Indexer.reindex(ids: score.quality_control_version_id)
  end

  defp on_event_insert(_error, _reindex), do: :noop

  defp on_upserted_score({:ok, %Score{quality_control_version_id: quality_control_version_id}}) do
    Indexer.reindex(ids: quality_control_version_id)
  end

  defp on_upserted_score(_error), do: :noop
end
