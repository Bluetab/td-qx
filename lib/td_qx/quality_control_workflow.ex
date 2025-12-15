defmodule TdQx.QualityControlWorkflow do
  @moduledoc """
  Version Workflow logic for Quality Controls
  """

  import TdQx.QualityControls.QualityControlVersion,
    only: [status_changeset: 2]

  alias Ecto.Multi
  alias TdQx.QualityControls
  alias TdQx.QualityControls.Audit
  alias TdQx.QualityControls.QualityControl
  alias TdQx.QualityControls.QualityControlVersion
  alias TdQx.Repo
  alias TdQx.Search.Indexer

  @valid_execution_statuses ~w(draft pending_approval published)

  def create_quality_control(params, opts \\ []) do
    user_id = Keyword.get(opts, :user_id)

    Multi.new()
    |> Multi.run(:quality_control, fn _, _ -> QualityControls.create_quality_control(params) end)
    |> Multi.run(:quality_control_version, fn _, %{quality_control: quality_control} ->
      QualityControls.create_quality_control_version(quality_control, params)
    end)
    |> Multi.run(:audit, fn _, %{quality_control_version: quality_control_version} ->
      Audit.publish(:quality_control_created, quality_control_version, user_id)
    end)
    |> Repo.transaction()
    |> reindex_quality_control()
  end

  def create_quality_control_draft(quality_control, params, opts \\ [])

  def create_quality_control_draft(
        %{latest_version: %{status: "published", version: version} = latest_version} =
          quality_control,
        params,
        opts
      ) do
    user_id = Keyword.get(opts, :user_id)

    Multi.new()
    |> Multi.run(:maybe_replace_published, fn _, _ ->
      maybe_replace_published(latest_version, params)
    end)
    |> Multi.run(:quality_control_version, fn _, _ ->
      QualityControls.create_quality_control_version(quality_control, params, version + 1)
    end)
    |> Multi.run(:audit, fn _, %{quality_control_version: quality_control_version} ->
      Audit.publish(:quality_control_version_draft_created, quality_control_version, user_id)
    end)
    |> Repo.transaction()
    |> reindex_quality_control()
  end

  def create_quality_control_draft(_, _, _),
    do: {:error, :invalid_action, "create_draft not published"}

  defp maybe_replace_published(latest_version, %{"status" => "published"}),
    do:
      latest_version
      |> status_changeset("versioned")
      |> Repo.update()

  defp maybe_replace_published(_, _), do: {:ok, nil}

  def update_quality_control_status(quality_control, action, opts \\ []) do
    user_id = Keyword.get(opts, :user_id)

    quality_control
    |> changesets_for_action(action)
    |> case do
      {:ok, changesets} ->
        changesets
        |> Enum.map(&validate_publish_changeset(&1, action))
        |> Enum.reduce(Multi.new(), &handle_multi_changeset/2)
        |> Multi.run(:audit, fn _repo, transaction_results ->
          transaction_results
          |> Map.values()
          |> Repo.preload([:quality_control])
          |> Enum.map(&{:quality_control_version_status_updated, &1})
          |> Audit.publish_all(user_id, %{action: action})
        end)
        |> Repo.transaction()
        |> handle_multi_result()
        |> preload_quality_control()
        |> reindex_quality_control()

      error ->
        error
    end
  end

  def update_quality_control_draft(_quality_control_version, _params, opts \\ [])

  def update_quality_control_draft(%{status: "draft"} = quality_control_version, params, opts) do
    user_id = Keyword.get(opts, :user_id)

    changeset =
      quality_control_version
      |> Repo.preload(:quality_control)
      |> QualityControlVersion.update_draft_changeset(params)

    Multi.new()
    |> Multi.update(:quality_control_version, changeset)
    |> Multi.run(:audit, fn _, %{quality_control_version: quality_control_version} ->
      Audit.publish(
        :quality_control_version_draft_updated,
        quality_control_version,
        user_id,
        %{changes: changeset.changes}
      )
    end)
    |> Repo.transaction()
    |> reindex_quality_control()
  end

  def update_quality_control_draft(_, _, _),
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

  def valid_action?(%QualityControlVersion{} = quality_control_version, action) do
    valid_action_for_version?(quality_control_version, action)
  end

  def valid_action?(
        %QualityControl{latest_version: %QualityControlVersion{} = quality_control_version},
        action
      ) do
    valid_action_for_version?(
      %QualityControlVersion{quality_control_version | latest: true},
      action
    )
  end

  def valid_action?(_, _), do: false

  defp valid_action_for_version?(
         %QualityControlVersion{status: status, latest: true} = latest_version,
         "publish"
       )
       when status in ["draft", "pending_approval"],
       do: QualityControlVersion.valid_publish_version(latest_version)

  defp valid_action_for_version?(
         %QualityControlVersion{status: "published", latest: true},
         "deprecate"
       ),
       do: true

  defp valid_action_for_version?(
         %QualityControlVersion{status: "deprecated", latest: true},
         "restore"
       ),
       do: true

  defp valid_action_for_version?(
         %QualityControlVersion{status: "rejected", latest: true},
         "send_to_draft"
       ),
       do: true

  defp valid_action_for_version?(
         %QualityControlVersion{status: "pending_approval", latest: true},
         "reject"
       ),
       do: true

  defp valid_action_for_version?(
         %QualityControlVersion{status: "draft", latest: true} = latest_version,
         "send_to_approval"
       ),
       do: QualityControlVersion.valid_publish_version(latest_version)

  defp valid_action_for_version?(%QualityControlVersion{status: "draft", latest: true}, "edit"),
    do: true

  defp valid_action_for_version?(
         %QualityControlVersion{status: "published", latest: true},
         "create_draft"
       ),
       do: true

  defp valid_action_for_version?(
         %QualityControlVersion{status: status, latest: true},
         "toggle_active"
       )
       when status != "deprecated",
       do: true

  defp valid_action_for_version?(%QualityControlVersion{status: status}, "execute")
       when status in @valid_execution_statuses,
       do: true

  defp valid_action_for_version?(%QualityControlVersion{status: "draft"}, "delete"), do: true

  defp valid_action_for_version?(%QualityControlVersion{latest: true}, "delete_score"), do: true
  defp valid_action_for_version?(%QualityControlVersion{latest: true}, "update_main"), do: true
  defp valid_action_for_version?(_, _), do: false

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

  def reindex_quality_control(
        {:ok,
         %QualityControlVersion{quality_control_id: quality_control_id} = quality_control_version}
      ) do
    Indexer.reindex(quality_control_ids: [quality_control_id])
    {:ok, quality_control_version}
  end

  def reindex_quality_control({:ok, %{quality_control_version: quality_control_version}}) do
    Indexer.reindex(quality_control_ids: [quality_control_version.quality_control.id])
    {:ok, quality_control_version}
  end

  def reindex_quality_control({:error, _, error, _}) do
    {:error, error}
  end

  def reindex_quality_control({:error, error}) do
    {:error, error}
  end
end
