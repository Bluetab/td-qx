defmodule TdQx.Search.Store do
  @moduledoc """
  Elasticsearch store implementation for Qx
  """

  @behaviour Elasticsearch.Store

  import Ecto.Query

  alias TdCluster.Cluster.TdDd.Tasks
  alias TdCluster.Cluster.TdDf
  alias TdQx.QualityControls
  alias TdQx.QualityControls.QualityControlVersion
  alias TdQx.Repo
  alias TdQx.Scores
  alias TdQx.Scores.ScoreGroup

  @impl true
  def stream(QualityControlVersion), do: stream(QualityControlVersion, [])

  @impl true
  def stream(ScoreGroup), do: stream(ScoreGroup, [])

  @impl true
  def stream(schema) do
    Repo.stream(schema)
  end

  @impl true
  def transaction(fun) do
    {:ok, result} = Repo.transaction(fun, timeout: :infinity)
    result
  end

  def stream(QualityControlVersion, params) when is_list(params) do
    {:ok, templates} = TdDf.list_templates_by_scope("quality_control")
    templates_map = Enum.into(templates, %{}, fn %{name: name} = template -> {name, template} end)
    count = get_count(QualityControlVersion, params)
    Tasks.log_start_stream(count)

    params
    |> QualityControls.quality_control_versions_query()
    |> Repo.stream()
    |> Stream.map(fn %{df_type: df_type} = quality_control_version ->
      Tasks.log_progress(1)
      Map.put(quality_control_version, :template, Map.get(templates_map, df_type))
    end)
  end

  def stream(ScoreGroup, ids) do
    {:ok, templates} = TdDf.list_templates_by_scope("qxe")
    templates_map = Enum.into(templates, %{}, fn %{name: name} = template -> {name, template} end)

    count = get_count(ScoreGroup, ids)

    Tasks.log_start_stream(count)

    ids
    |> Scores.score_groups_query()
    |> Repo.stream()
    |> Stream.map(fn %{df_type: df_type} = score_group ->
      Tasks.log_progress(1)
      Map.put(score_group, :template, Map.get(templates_map, df_type))
    end)
  end

  def stream(schema, ids) do
    from(item in schema)
    |> where([item], item.id in ^ids)
    |> select([item], item)
    |> Repo.stream()
  end

  def get_count(QualityControlVersion, []) do
    Repo.aggregate(QualityControlVersion, :count, :id)
  end

  def get_count(ScoreGroup, []) do
    Repo.aggregate(ScoreGroup, :count, :id)
  end

  def get_count(QualityControlVersion, params) do
    params
    |> QualityControls.quality_control_versions_filters()
    |> Repo.aggregate(:count, :id)
  end

  def get_count(ScoreGroup, ids) do
    ids
    |> Scores.score_groups_query()
    |> Repo.aggregate(:count, :id)
  end
end
