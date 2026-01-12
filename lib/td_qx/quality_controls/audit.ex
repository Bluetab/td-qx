defmodule TdQx.QualityControls.Audit do
  @moduledoc """
  Audit event publishing for Quality Controls.
  """

  alias TdCache.Audit
  alias TdCache.TaxonomyCache
  alias TdQx.Audit.Message
  alias TdQx.QualityControls.QualityControl
  alias TdQx.QualityControls.QualityControlVersion

  @quality_control_fields [
    :id,
    :source_id,
    :domain_ids,
    :active
  ]

  @quality_control_version_fields [
    :name,
    :version,
    :status,
    :control_mode,
    :quality_control_id,
    :df_type,
    :dynamic_content,
    :score_criteria
  ]

  def publish(_event_type, _control_or_version, _user_id, _metadata \\ %{})

  def publish(event_type, %QualityControl{} = quality_control, user_id, metadata) do
    event = build_event(event_type, quality_control, user_id, metadata)
    Audit.publish(event)
  end

  def publish(event_type, %QualityControlVersion{} = version, user_id, metadata) do
    event = build_event(event_type, version, user_id, metadata)
    Audit.publish(event)
  end

  @doc """
  Publishes multiple audit events in batch.
  """
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

  def enrich_domain_ids(%{domain_ids: domain_ids} = payload) when is_list(domain_ids) do
    current_hierarchical_domain_ids =
      Map.new(domain_ids, fn domain_id ->
        {domain_id, TaxonomyCache.reaching_domain_ids(domain_id)}
      end)

    hierarchical_domain_ids =
      current_hierarchical_domain_ids
      |> Map.values()
      |> List.flatten()
      |> Enum.uniq()

    payload
    |> Map.put(:domain_id, List.first(domain_ids))
    |> Map.put(:domain_ids, hierarchical_domain_ids)
    |> Map.put(:current_domains_ids, current_hierarchical_domain_ids)
  end

  def enrich_domain_ids(payload), do: payload

  defp build_event(event_type, entity, user_id, metadata) do
    %{
      event: event_type,
      resource_type: "quality_control",
      resource_id: get_resource_id(entity),
      user_id: user_id,
      payload: build_payload(entity, metadata)
    }
  end

  defp build_payload(%QualityControl{} = quality_control, metadata) do
    quality_control
    |> payload_from_quality_control()
    |> Message.apply_metadata(metadata, @quality_control_fields)
    |> maybe_enrich_domains_names_metadata()
    |> maybe_enrich_current_domains()
  end

  defp build_payload(%QualityControlVersion{} = version, metadata) do
    version
    |> payload_from_version()
    |> Message.apply_metadata(metadata, @quality_control_version_fields)
    |> maybe_add_score_criteria_changes(metadata)
  end

  defp get_resource_id(%QualityControl{id: id}), do: id

  defp get_resource_id(%QualityControlVersion{
         quality_control: %QualityControl{} = quality_control
       }) do
    get_resource_id(quality_control)
  end

  defp get_resource_id(%QualityControlVersion{quality_control_id: quality_control_id}),
    do: quality_control_id

  defp payload_from_quality_control(%QualityControl{} = quality_control) do
    quality_control
    |> Map.take(@quality_control_fields)
    |> Map.put(:quality_control_id, quality_control.id)
    |> enrich_domain_ids()
  end

  defp payload_from_version(
         %QualityControlVersion{quality_control: %QualityControl{} = quality_control} = version
       ) do
    version_data =
      version
      |> Map.take(@quality_control_version_fields)
      |> Map.put(:quality_control_version_id, version.id)

    quality_control
    |> payload_from_quality_control()
    |> Map.merge(version_data)
  end

  defp maybe_add_score_criteria_changes(%{changes: %{control_mode: _}} = payload, _metadata) do
    Map.delete(payload, :score_criteria)
  end

  defp maybe_add_score_criteria_changes(
         %{changes: %{score_criteria: score_criteria_changes} = changes} = payload,
         %{score_criteria: current_score_criteria, control_mode: current_control_mode}
       ) do
    control_mode_key = :"#{current_control_mode}"
    current_data = Map.from_struct(Map.get(current_score_criteria, control_mode_key))
    new_data = Map.get(score_criteria_changes, control_mode_key)

    updated_changes =
      if current_data == new_data do
        Map.delete(changes, :score_criteria)
      else
        changes
      end

    payload
    |> Map.put(:changes, updated_changes)
    |> Map.delete(:score_criteria)
  end

  defp maybe_add_score_criteria_changes(payload, _metadata) do
    Map.delete(payload, :score_criteria)
  end

  defp maybe_enrich_domains_names_metadata(%{changes: %{domain_ids: domain_ids}} = payload) do
    domains = enrich_domains_names(domain_ids)
    Map.put(payload, :changes, %{domains: domains})
  end

  defp maybe_enrich_domains_names_metadata(payload), do: payload

  defp maybe_enrich_current_domains(
         %{changes: %{domains: _}, current_domains: current_domains} = payload
       ) do
    domains = enrich_domains_names(current_domains)
    Map.put(payload, :current_domains, domains)
  end

  defp maybe_enrich_current_domains(payload), do: payload

  defp enrich_domains_names(domain_ids) do
    Enum.map(domain_ids, fn domain_id ->
      case TaxonomyCache.get_domain(domain_id) do
        nil -> %{id: domain_id, name: domain_id}
        domain -> Map.take(domain, [:id, :name, :external_id])
      end
    end)
  end
end
