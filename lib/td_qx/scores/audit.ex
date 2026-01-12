defmodule TdQx.Scores.Audit do
  @moduledoc """
  Audit event publishing for Scores.
  """

  alias TdCache.Audit
  alias TdQx.Audit.Message
  alias TdQx.QualityControls
  alias TdQx.QualityControls.Audit, as: QualityControlsAudit
  alias TdQx.QualityControls.QualityControl
  alias TdQx.QualityControls.QualityControlVersion
  alias TdQx.Scores
  alias TdQx.Scores.Score
  alias TdQx.Scores.ScoreEvent
  alias TdQx.Scores.ScoreGroup

  @score_group_fields [
    :id,
    :df_type,
    :dynamic_content,
    :created_by,
    :inserted_at,
    :updated_at
  ]
  @score_fields [
    :score_type,
    :quality_control_status,
    :score_content,
    :details,
    :execution_timestamp,
    :group_id,
    :quality_control_version_id,
    :result,
    :latest_event_message,
    :name,
    :control_mode,
    :score_criteria,
    :version,
    :quality_control_id,
    :domain_ids,
    :current_domains_ids
  ]
  @score_event_fields [
    :type,
    :message,
    :ttl,
    :score_id,
    :inserted_at,
    :updated_at
  ]
  @quality_control_fields [
    :quality_control_id,
    :quality_control_version_id,
    :domain_ids
  ]
  def publish(_event_type, _score_group_or_score_or_score_event, _user_id, _metadata \\ %{})

  def publish(event_type, %ScoreGroup{} = score_group, user_id, metadata) do
    event = build_event(event_type, score_group, user_id, metadata)
    Audit.publish(event)
  end

  def publish(event_type, %Score{} = score, user_id, metadata) do
    event = build_event(event_type, score, user_id, metadata)
    Audit.publish(event)
  end

  def publish(event_type, %ScoreEvent{} = score_event, user_id, metadata) do
    event = build_event(event_type, score_event, user_id, metadata)
    Audit.publish(event)
  end

  def publish_all(events, user_id, metadata \\ %{}) do
    events
    |> Enum.map(fn
      {event_type, entity} ->
        build_event(event_type, entity, user_id, metadata)

      {event_type, entity, event_metadata} ->
        event_metadata = Map.merge(metadata, event_metadata)
        build_event(event_type, entity, user_id, event_metadata)
    end)
    |> Audit.publish_all()
  end

  defp build_event(event_type, entity, user_id, metadata) do
    %{
      event: event_type,
      resource_type: get_resource_type(entity),
      resource_id: get_resource_id(entity),
      user_id: user_id,
      payload: build_payload(entity, metadata)
    }
  end

  defp build_payload(%ScoreGroup{} = score_group, metadata) do
    score_group
    |> Map.take(@score_group_fields)
    |> Message.apply_metadata(metadata, @score_group_fields)
  end

  defp build_payload(%Score{} = score, metadata) do
    score
    |> enrich()
    |> Map.take(@score_fields ++ @quality_control_fields)
    |> Message.apply_metadata(metadata, @score_fields)
  end

  defp build_payload(%ScoreEvent{} = score_event, metadata) do
    score_event
    |> enrich()
    |> Map.take(@score_event_fields ++ @quality_control_fields)
    |> Map.put(:score_event_id, score_event.id)
    |> Map.put(:status, score_event.type)
    |> Message.apply_metadata(metadata, @score_event_fields)
  end

  defp get_resource_id(%ScoreGroup{id: id}), do: id
  defp get_resource_id(%Score{id: id}), do: id
  defp get_resource_id(%ScoreEvent{score_id: id}), do: id

  defp get_resource_type(%ScoreGroup{}), do: "score_group"
  defp get_resource_type(%Score{}), do: "score"
  defp get_resource_type(%ScoreEvent{}), do: "score"

  defp enrich(%Score{quality_control_version_id: quality_control_version_id} = payload) do
    version = QualityControls.get_quality_control_version!(quality_control_version_id)

    payload
    |> enrich_result(version)
    |> enrich_score_criteria(version)
    |> Map.put(:quality_control_id, version.quality_control.id)
    |> Map.put(:version, version.version)
    |> Map.put(:quality_control_version_id, quality_control_version_id)
    |> Map.put(:domain_ids, version.quality_control.domain_ids)
    |> Map.put(:name, version.name)
    |> Map.put(:control_mode, version.control_mode)
    |> QualityControlsAudit.enrich_domain_ids()
  end

  defp enrich(
         %ScoreEvent{
           score: %Score{
             quality_control_version: %QualityControlVersion{
               quality_control: %QualityControl{id: quality_control_id, domain_ids: domain_ids},
               name: name,
               id: id,
               control_mode: control_mode,
               version: version
             }
           }
         } =
           payload
       ) do
    payload
    |> Map.put(:quality_control_id, quality_control_id)
    |> Map.put(:quality_control_version_id, id)
    |> Map.put(:domain_ids, domain_ids)
    |> Map.put(:name, name)
    |> Map.put(:control_mode, control_mode)
    |> Map.put(:version, version)
  end

  defp enrich(payload), do: payload

  defp enrich_result(%Score{score_content: %{}} = score, %QualityControlVersion{} = version) do
    Map.put(score, :result, Scores.score_content(version, score))
  end

  defp enrich_result(payload, _version), do: payload

  defp enrich_score_criteria(payload, %QualityControlVersion{score_criteria: %{} = score_criteria}) do
    Map.put(payload, :score_criteria, score_criteria)
  end

  defp enrich_score_criteria(payload, _version), do: payload
end
