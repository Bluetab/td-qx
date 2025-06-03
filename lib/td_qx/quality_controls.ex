defmodule TdQx.QualityControls do
  @moduledoc """
  The QualityControls context.
  """

  import Ecto.Query, warn: false

  alias TdCache.TaxonomyCache
  alias TdQx.DataViews
  alias TdQx.QualityControls.ControlProperties
  alias TdQx.QualityControls.QualityControl
  alias TdQx.QualityControls.QualityControlVersion
  alias TdQx.Scores
  alias TdQx.Scores.Score
  alias TdQx.Scores.ScoreEvent
  alias TdQx.Search.Indexer

  alias TdQx.Repo

  defdelegate authorize(action, user, params), to: __MODULE__.Policy

  @doc """
  Returns the list of quality_controls.

  ## Examples

      iex> list_quality_controls()
      [%QualityControl{}, ...]

  """
  def list_quality_controls do
    QualityControl
    |> preload(:published_version)
    |> Repo.all()
  end

  def list_published_versions_by_source_id(source_id) do
    QualityControlVersion
    |> join(:inner, [qcv], qc in assoc(qcv, :quality_control))
    |> where([qcv, qc], qc.source_id == ^source_id and qcv.status == "published")
    |> preload([_, qc], quality_control: qc)
    |> Repo.all()
  end

  def quality_control_latest_versions_query do
    last_version_subquery = latest_version_subquery()

    from(c in QualityControl,
      as: :quality_control,
      inner_lateral_join: v in subquery(last_version_subquery),
      on: true,
      select_merge: %{latest_version: v}
    )
  end

  def list_quality_control_latest_versions do
    Repo.all(quality_control_latest_versions_query())
  end

  def get_quality_control(id) do
    Repo.get(QualityControl, id)
  end

  def get_quality_control_with_latest_result(%{id: quality_control_id}) do
    [quality_control_id: quality_control_id, preload: :status, statuses: ["FAILED", "SUCCEEDED"]]
    |> Scores.list_scores()
    |> case do
      [] ->
        %{}

      result ->
        result
        |> Enum.max_by(& &1.execution_timestamp)
        |> Map.take([
          :id,
          :group_id,
          :quality_control_version_id,
          :latest_event_message,
          :execution_timestamp,
          :type,
          :details,
          :status
        ])
    end
    |> then(&{:last_execution_result, &1})
  end

  @doc """
  Gets a single quality_control.

  Raises `Ecto.NoResultsError` if the Quality control does not exist.

  ## Examples

      iex> get_quality_control!(123)
      %QualityControl{}

      iex> get_quality_control!(456)
      ** (Ecto.NoResultsError)

  """
  def get_quality_control!(id, opts \\ []),
    do:
      opts
      |> Enum.reduce(QualityControl, fn
        {:preload, value}, query -> preload(query, ^value)
        _, query -> query
      end)
      |> where(id: ^id)
      |> join(:left, [q], v in subquery(latest_version_query(id)), on: true)
      |> select_merge([q, v], %{latest_version: v})
      |> Repo.one!()
      |> enrich(Keyword.get(opts, :enrich, []))

  def latest_version_query(id) do
    QualityControlVersion
    |> where([q], q.quality_control_id == ^id)
    |> order_by(desc: :version)
    |> limit(1)
  end

  @doc """
  Creates a quality_control.

  ## Examples

      iex> create_quality_control(%{field: value})
      {:ok, %QualityControl{}}

      iex> create_quality_control(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_quality_control(attrs \\ %{}) do
    %QualityControl{}
    |> QualityControl.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a quality_control.

  ## Examples

      iex> update_quality_control(quality_control, %{field: new_value})
      {:ok, %QualityControl{}}

      iex> update_quality_control(quality_control, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_quality_control(%QualityControl{} = quality_control, attrs) do
    quality_control
    |> QualityControl.update_changeset(attrs)
    |> Repo.update()
    |> TdQx.QualityControlWorkflow.reindex_quality_control()
  end

  @doc """
  Deletes a quality_control.

  ## Examples

      iex> delete_quality_control(quality_control)
      {:ok, %QualityControl{}}

      iex> delete_quality_control(quality_control)
      {:error, %Ecto.Changeset{}}

  """
  def delete_quality_control(%QualityControl{} = quality_control) do
    Repo.delete(quality_control)
  end

  def quality_control_versions_filters(params) do
    Enum.reduce(params, QualityControlVersion, fn
      {:quality_control_ids, ids}, q when is_list(ids) ->
        where(q, [qcv], qcv.quality_control_id in ^ids)

      {:quality_control_ids, id}, q ->
        where(q, [qcv], qcv.quality_control_id == ^id)

      {:ids, ids}, q when is_list(ids) ->
        where(q, [qcv], qcv.id in ^ids)

      {:ids, id}, q ->
        where(q, [qcv], qcv.id == ^id)

      _other, q ->
        q
    end)
  end

  def quality_control_versions_query(params \\ []) do
    last_version_subquery = latest_version_subquery()

    last_score_subquery =
      Scores.latest_score_subquery(
        parent_quality_control_version: :qcv,
        preload: :status
      )

    final_score_subquery =
      QualityControlVersion
      |> where([qcv], qcv.quality_control_id == parent_as(:qcv).quality_control_id)
      |> where([qcv], qcv.status in ["published", "versioned", "deprecated"])
      |> join(:inner, [qcv], s in Score,
        on:
          s.quality_control_version_id == qcv.id and
            s.quality_control_status == "published"
      )
      |> join(:inner, [qcv, s], se in ScoreEvent, on: s.id == se.score_id)
      |> where([qcv, s, se], se.type in ["FAILED", "SUCCEEDED"])
      |> order_by([qcv, s, se],
        desc: qcv.version,
        desc: s.execution_timestamp,
        desc: se.inserted_at
      )
      |> limit(1)
      |> select([_qcv, s, se], %Score{s | type: se.type, status: se.type, message: se.message})

    params
    |> quality_control_versions_filters()
    |> from(as: :qcv)
    |> join(:inner, [qcv, qc], qc in assoc(qcv, :quality_control), as: :quality_control)
    |> join(:left_lateral, [qcv, _qc], lqcv in subquery(last_version_subquery),
      on: lqcv.id == qcv.id
    )
    |> join(:left_lateral, [qcv, _qc, _lqcv], les in subquery(last_score_subquery), on: true)
    |> join(:left_lateral, [qcv, _qc, _lqcv, _les], lps in subquery(final_score_subquery),
      on: true
    )
    |> select_merge([qcv, qc, lqcv, les, lps], %{
      latest: not is_nil(lqcv),
      quality_control: qc,
      latest_score: les,
      final_score: lps
    })
  end

  def list_quality_control_versions(params \\ []) do
    params
    |> quality_control_versions_query()
    |> Repo.all()
  end

  @doc """
  Gets a single quality_control_version.

  Raises `Ecto.NoResultsError` if the Quality control version does not exist.

  ## Examples

      iex> get_quality_control_version!(123)
      %QualityControlVersion{}

      iex> get_quality_control_version!(456)
      ** (Ecto.NoResultsError)

  """
  def get_quality_control_version!(id), do: Repo.get!(QualityControlVersion, id)

  def get_quality_control_version(quality_control_id, version, opts \\ []) do
    preload =
      opts
      |> Keyword.get(:preload, [])
      |> Enum.map(fn
        {:quality_control, {:versions, :desc}} ->
          {:quality_control, versions: order_by(QualityControlVersion, desc: :version)}

        other ->
          other
      end)

    enrich = Keyword.get(opts, :enrich, [])
    last_version_subquery = latest_version_subquery()

    QualityControlVersion
    |> where([qcv], qcv.quality_control_id == ^quality_control_id)
    |> where([qcv], qcv.version == ^version)
    |> join(:inner, [qcv, qc], qc in assoc(qcv, :quality_control), as: :quality_control)
    |> join(:left_lateral, [qcv, _qc], lqcv in subquery(last_version_subquery),
      on: lqcv.id == qcv.id
    )
    |> preload(^preload)
    |> select_merge([qcv, qc, lqcv], %{latest: not is_nil(lqcv), quality_control: qc})
    |> Repo.one()
    |> enrich(enrich)
  end

  @doc """
  Creates a quality_control_version.

  ## Examples

      iex> create_quality_control_version(%QualityControl{} = quality_control, %{field: value}, version)
      {:ok, %QualityControlVersion{}}

      iex> create_quality_control_version(nil, %{field: bad_value}, nil)
      {:error, %Ecto.Changeset{}}

  """

  def create_quality_control_version(
        %QualityControl{} = quality_control,
        attrs,
        version \\ 1
      ) do
    quality_control
    |> QualityControlVersion.create_changeset(attrs, version)
    |> Repo.insert()
  end

  @doc """
  Deletes a quality_control_version.

  ## Examples

      iex> delete_quality_control_version(quality_control_version)
      {:ok, %QualityControlVersion{}}

      iex> delete_quality_control_version(quality_control_version)
      {:error, %Ecto.Changeset{}}

  """
  def delete_quality_control_version(
        %QualityControlVersion{id: id, status: "draft"} = quality_control_version
      ) do
    quality_control_version
    |> Repo.preload(quality_control: :versions)
    |> then(fn
      %QualityControlVersion{
        quality_control:
          %QualityControl{versions: [%QualityControlVersion{id: ^id}]} = quality_control
      } ->
        Repo.delete(quality_control)

      %QualityControlVersion{quality_control: %QualityControl{versions: [_ | _]}} ->
        Repo.delete(quality_control_version)
    end)
    |> tap(fn
      {:ok, _response} ->
        Indexer.delete([id])

      _error ->
        :noop
    end)
  end

  def delete_quality_control_version(%QualityControlVersion{status: _other}) do
    {:error, :forbidden}
  end

  def count_unique_name(name, quality_control_id) do
    QualityControlVersion
    |> where(
      [v],
      v.name == ^name and v.quality_control_id != ^quality_control_id and
        v.status not in ["deprecated", "versioned"]
    )
    |> select([v], count(v.id))
    |> Repo.one!()
  end

  defp latest_version_subquery do
    QualityControlVersion
    |> where([q], q.quality_control_id == parent_as(:quality_control).id)
    |> order_by(desc: :version)
    |> limit(1)
    |> select([latest], latest)
  end

  defp enrich(%QualityControl{} = qc, enrich_opts),
    do: Enum.reduce(enrich_opts, qc, &enrich_step/2)

  defp enrich(%QualityControlVersion{} = quality_control_version, enrich_opts),
    do: Enum.reduce(enrich_opts, quality_control_version, &enrich_step/2)

  defp enrich(error, _), do: error

  defp enrich_step(:domains, %QualityControl{domain_ids: domain_ids} = quality_control) do
    domain_ids
    |> Enum.map(&TaxonomyCache.get_domain/1)
    |> then(&Map.put(quality_control, :domains, &1))
  end

  defp enrich_step(
         :domains,
         %QualityControlVersion{quality_control: %QualityControl{} = quality_control} =
           quality_control_version
       ) do
    %QualityControlVersion{
      quality_control_version
      | quality_control: enrich_step(:domains, quality_control)
    }
  end

  defp enrich_step(
         :control_properties,
         %QualityControl{
           latest_version: %{control_properties: %ControlProperties{} = control_properties}
         } =
           quality_control
       ) do
    Map.update!(
      quality_control,
      :latest_version,
      fn version ->
        Map.update!(version, :control_properties, fn _ ->
          ControlProperties.enrich_resources(control_properties, &DataViews.enrich_resource/1)
        end)
      end
    )
  end

  defp enrich_step(
         :control_properties,
         %QualityControlVersion{control_properties: %ControlProperties{} = control_properties} =
           quality_control_version
       ) do
    %QualityControlVersion{
      quality_control_version
      | control_properties:
          ControlProperties.enrich_resources(control_properties, &DataViews.enrich_resource/1)
    }
  end

  defp enrich_step(_, resource), do: resource
end
