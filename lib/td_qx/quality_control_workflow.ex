defmodule TdQx.QualityControlWorkflow do
  @moduledoc """
  Version Workflow logic for Quality Controls
  """

  import TdQx.QualityControls.QualityControlVersion,
    only: [status_changeset: 2]

  alias Ecto.Multi
  alias TdCore.Search
  alias TdQx.QualityControls
  alias TdQx.QualityControls.QualityControlVersion
  alias TdQx.Repo

  def create_quality_control(params) do
    Multi.new()
    |> Multi.run(:quality_control, fn _, _ -> QualityControls.create_quality_control(params) end)
    |> Multi.run(:quality_control_version, fn _, %{quality_control: quality_control} ->
      QualityControls.create_quality_control_version(quality_control, params)
    end)
    |> Repo.transaction()
    |> reindex_quality_control()
  end

  def create_quality_control_draft(
        %{latest_version: %{status: "published", version: version} = latest_version} =
          quality_control,
        params
      ) do
    Multi.new()
    |> Multi.run(:maybe_replace_published, fn _, _ ->
      maybe_replace_published(latest_version, params)
    end)
    |> Multi.run(:quality_control_version, fn _, _ ->
      QualityControls.create_quality_control_version(quality_control, params, version + 1)
    end)
    |> Repo.transaction()
    |> reindex_quality_control()
  end

  def create_quality_control_draft(_, _),
    do: {:error, :invalid_action, "create_draft not published"}

  defp maybe_replace_published(latest_version, %{"status" => "published"}),
    do:
      latest_version
      |> status_changeset("versioned")
      |> Repo.update()

  defp maybe_replace_published(_, _), do: {:ok, nil}

  def update_quality_control_status(quality_control, action) do
    quality_control
    |> changesets_for_action(action)
    |> case do
      {:ok, changesets} ->
        changesets
        |> Enum.map(&validate_publish_changeset(&1, action))
        |> Enum.reduce(Multi.new(), &handle_multi_changeset/2)
        |> Repo.transaction()
        |> handle_multi_result()
        |> preload_quality_control()
        |> reindex_quality_control()

      error ->
        error
    end
  end

  def update_quality_control_draft(%{status: "draft"} = quality_control_version, params) do
    quality_control_version
    |> QualityControlVersion.update_draft_changeset(params)
    |> Repo.update()
    |> case do
      {:ok, qcv} -> {:ok, Repo.preload(qcv, :quality_control)}
      error -> error
    end
    |> reindex_quality_control()
  end

  def update_quality_control_draft(_, _),
    do: {:error, :invalid_action, "update_draft not a draft"}

  defp handle_multi_changeset({:update, %{changes: %{status: status}} = changeset}, multi),
    do: Multi.update(multi, status, changeset)

  defp handle_multi_changeset({:delete, version}, multi),
    do: Multi.delete(multi, "delete", version)

  defp handle_multi_result({:ok, %{"published" => qcv}}), do: {:ok, qcv}
  defp handle_multi_result({:ok, %{"deprecated" => qcv}}), do: {:ok, qcv}
  defp handle_multi_result({:ok, %{"draft" => qcv}}), do: {:ok, qcv}
  defp handle_multi_result({:ok, %{"rejected" => qcv}}), do: {:ok, qcv}
  defp handle_multi_result({:ok, %{"pending_approval" => qcv}}), do: {:ok, qcv}
  defp handle_multi_result(error), do: error

  defp preload_quality_control({:ok, qcv}), do: {:ok, Repo.preload(qcv, :quality_control)}
  defp preload_quality_control(error), do: error

  def valid_action?(%{latest_version: %{status: status} = latest_version}, "publish")
      when status in ["draft", "pending_approval"],
      do: QualityControlVersion.valid_publish_version(latest_version)

  def valid_action?(%{published_version: %QualityControlVersion{}}, "deprecate"),
    do: true

  def valid_action?(%{latest_version: %{status: "deprecated"}}, "restore"),
    do: true

  def valid_action?(%{latest_version: %{status: "rejected"}}, "send_to_draft"),
    do: true

  def valid_action?(%{latest_version: %{status: "pending_approval"}}, "reject"),
    do: true

  def valid_action?(%{latest_version: %{status: "draft"} = latest_version}, "send_to_approval"),
    do: QualityControlVersion.valid_publish_version(latest_version)

  def valid_action?(%{latest_version: %{status: "draft"}}, "edit"),
    do: true

  def valid_action?(%{latest_version: %{status: "published"}}, "create_draft"),
    do: true

  def valid_action?(_, _), do: false

  def changesets_for_action(
        %{latest_version: %{status: status} = latest_version, published_version: nil},
        "publish"
      )
      when status in ["draft", "pending_approval"],
      do: {:ok, [{:update, status_changeset(latest_version, "published")}]}

  def changesets_for_action(
        %{
          latest_version: %{status: status} = latest_version,
          published_version: published_version
        },
        "publish"
      )
      when status in ["draft", "pending_approval"],
      do:
        {:ok,
         [
           {:update, status_changeset(published_version, "versioned")},
           {:update, status_changeset(latest_version, "published")}
         ]}

  def changesets_for_action(
        %{latest_version: %{status: "published"}, published_version: published_version},
        "deprecate"
      )
      when not is_nil(published_version),
      do: {:ok, [{:update, status_changeset(published_version, "deprecated")}]}

  def changesets_for_action(
        %{latest_version: latest_version, published_version: published_version},
        "deprecate"
      )
      when not is_nil(published_version),
      do:
        {:ok,
         [
           {:delete, latest_version},
           {:update, status_changeset(published_version, "deprecated")}
         ]}

  def changesets_for_action(
        %{latest_version: %{status: "deprecated"} = latest_version},
        "restore"
      ),
      do: {:ok, [{:update, status_changeset(latest_version, "published")}]}

  def changesets_for_action(
        %{latest_version: %{status: "pending_approval"} = latest_version},
        "reject"
      ),
      do: {:ok, [{:update, status_changeset(latest_version, "rejected")}]}

  def changesets_for_action(
        %{latest_version: %{status: "rejected"} = latest_version},
        "send_to_draft"
      ),
      do: {:ok, [{:update, status_changeset(latest_version, "draft")}]}

  def changesets_for_action(%{latest_version: %{status: "draft"} = version}, "send_to_approval"),
    do: {:ok, [{:update, status_changeset(version, "pending_approval")}]}

  def changesets_for_action(nil, _),
    do: {:error, :invalid_quality_control}

  def changesets_for_action(_, action),
    do: {:error, :invalid_action, action}

  def validate_publish_changeset(
        {:update, %{changes: %{status: target_status}} = changeset},
        action
      )
      when target_status in ["published", "pending_approval"] and
             action in ["publish", "send_to_approval"],
      do: {:update, QualityControlVersion.validate_publish_changeset(changeset)}

  def validate_publish_changeset({:update, _} = change, _), do: change
  def validate_publish_changeset({:delete, _} = change, _), do: change

  defp reindex_quality_control(
         {:ok,
          %QualityControlVersion{quality_control_id: quality_control_id} = quality_control_version}
       ) do
    Search.IndexWorker.reindex(:quality_controls, [quality_control_id])
    {:ok, quality_control_version}
  end

  defp reindex_quality_control({:ok, %{quality_control_version: quality_control_version}}) do
    Search.IndexWorker.reindex(:quality_controls, [quality_control_version.quality_control_id])
    {:ok, quality_control_version}
  end

  defp reindex_quality_control({:error, _, error, _}) do
    {:error, error}
  end

  defp reindex_quality_control({:error, error}) do
    {:error, error}
  end
end
