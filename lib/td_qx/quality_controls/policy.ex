defmodule TdQx.QualityControls.Policy do
  @moduledoc "Authorization rules for TdQx.QualityControls"

  @behaviour Bodyguard.Policy

  alias TdCore.Auth.Permissions
  alias TdQx.QualityControls.QualityControl
  alias TdQx.QualityControls.QualityControlVersion

  # Admin accounts can do anything with data sets
  def authorize(_action, %{role: "admin"}, _params), do: true

  def authorize(:reindex, %{role: "service"}, _params), do: true

  def authorize(:search, %{} = claims, _params),
    do: Permissions.authorized?(claims, :view_quality_controls)

  def authorize(:execute, %{} = claims, _params),
    do: Permissions.authorized?(claims, :execute_quality_controls)

  def authorize(:create, %{} = claims, {domain_ids, "published"}),
    do: Permissions.all_authorized?(claims, :manage_quality_controls, domain_ids)

  def authorize(:create, %{} = claims, {domain_ids, _}),
    do: Permissions.all_authorized?(claims, :write_quality_controls, domain_ids)

  def authorize(
        :create_draft,
        %{} = claims,
        {%QualityControl{domain_ids: domain_ids}, "published"}
      ),
      do: Permissions.all_authorized?(claims, :manage_quality_controls, domain_ids)

  def authorize(:create_draft, %{} = claims, {%QualityControl{domain_ids: domain_ids}, _}),
    do: Permissions.all_authorized?(claims, :write_quality_controls, domain_ids)

  def authorize(:update_draft, %{} = claims, %QualityControl{domain_ids: domain_ids}),
    do: Permissions.all_authorized?(claims, :write_quality_controls, domain_ids)

  def authorize(:update_main, %{} = claims, %QualityControl{domain_ids: domain_ids}),
    do: Permissions.all_authorized?(claims, :manage_quality_controls, domain_ids)

  def authorize(:show, %{} = claims, %QualityControl{domain_ids: domain_ids}),
    do: Permissions.authorized?(claims, :view_quality_controls, domain_ids)

  def authorize(action, %{} = claims, %QualityControl{domain_ids: domain_ids})
      when action in [
             "send_to_approval",
             "send_to_draft",
             "edit",
             "create_draft"
           ],
      do: Permissions.all_authorized?(claims, :write_quality_controls, domain_ids)

  def authorize(action, %{} = claims, %QualityControl{domain_ids: domain_ids})
      when action in [
             "reject",
             "publish",
             "restore",
             "deprecate",
             "toggle_active",
             "delete_score"
           ],
      do: Permissions.all_authorized?(claims, :manage_quality_controls, domain_ids)

  def authorize(action, %{} = claims, %QualityControl{domain_ids: domain_ids})
      when action in [
             "execute"
           ],
      do: Permissions.all_authorized?(claims, :execute_quality_controls, domain_ids)

  def authorize(:delete, %{} = claims, %QualityControlVersion{
        status: "draft",
        quality_control: %QualityControl{domain_ids: domain_ids}
      }),
      do: Permissions.all_authorized?(claims, :manage_quality_controls, domain_ids)

  # No other users can do nothing
  def authorize(_action, _claims, _params), do: false
end
