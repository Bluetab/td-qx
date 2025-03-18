defmodule TdQx.Search.Store do
  @moduledoc """
  Elasticsearch store implementation for Qx
  """

  @behaviour Elasticsearch.Store

  import Ecto.Query

  alias TdCluster.Cluster.TdDd.Tasks
  alias TdCluster.Cluster.TdDf
  alias TdQx.QualityControls
  alias TdQx.QualityControls.QualityControl
  alias TdQx.Repo
  alias TdQx.Scores
  alias TdQx.Scores.ScoreGroup

  @impl true
  def stream(QualityControl) do
    {:ok, templates} = TdDf.list_templates_by_scope("quality_control")

    templates_map = Enum.into(templates, %{}, fn %{name: name} = template -> {name, template} end)

    count = Repo.aggregate(QualityControl, :count, :id)
    Tasks.log_start_stream(count)

    QualityControls.quality_control_latest_versions_query()
    |> Repo.stream()
    |> Stream.map(fn %{latest_version: %{df_type: df_type}} = quality_control ->
      Tasks.log_progress(1)
      Map.put(quality_control, :template, Map.get(templates_map, df_type))
    end)
  end

  @impl true
  def stream(ScoreGroup) do
    {:ok, templates} = TdDf.list_templates_by_scope("qxe")

    templates_map = Enum.into(templates, %{}, fn %{name: name} = template -> {name, template} end)

    count = Repo.aggregate(ScoreGroup, :count, :id)

    Tasks.log_start_stream(count)

    []
    |> Scores.score_groups_query()
    |> Repo.stream()
    |> Stream.map(fn %{df_type: df_type} = score_group ->
      Tasks.log_progress(1)
      Map.put(score_group, :template, Map.get(templates_map, df_type))
    end)
  end

  @impl true
  def stream(schema) do
    schema
    |> Repo.stream()
  end

  @impl true
  def transaction(fun) do
    {:ok, result} = Repo.transaction(fun, timeout: :infinity)
    result
  end

  def stream(ScoreGroup, ids) do
    {:ok, templates} = TdDf.list_templates_by_scope("qxe")

    templates_map = Enum.into(templates, %{}, fn %{name: name} = template -> {name, template} end)

    count = Enum.count(ids)

    Tasks.log_start_stream(count)

    [ids: ids]
    |> Scores.score_groups_query()
    |> Repo.stream()
    |> Stream.map(fn %{df_type: df_type} = score_group ->
      Tasks.log_progress(1)
      Map.put(score_group, :template, Map.get(templates_map, df_type))
    end)
  end

  def stream(QualityControl, ids) do
    {:ok, templates} = TdDf.list_templates_by_scope("quality_control")

    templates_map = Enum.into(templates, %{}, fn %{name: name} = template -> {name, template} end)

    count = Repo.aggregate(QualityControl, :count, :id)
    Tasks.log_start_stream(count)

    QualityControls.quality_control_latest_versions_query()
    |> where([qc], qc.id in ^ids)
    |> Repo.stream()
    |> Stream.map(fn %{latest_version: %{df_type: df_type}} = quality_control ->
      Tasks.log_progress(1)
      Map.put(quality_control, :template, Map.get(templates_map, df_type))
    end)
  end

  def stream(schema, ids) do
    from(item in schema)
    |> where([item], item.id in ^ids)
    |> select([item], item)
    |> Repo.stream()
  end
end
