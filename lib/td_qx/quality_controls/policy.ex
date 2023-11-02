defmodule TdQx.QualityControls.Policy do
  @moduledoc "Authorization rules for TdQx.QualityControls"

  @behaviour Bodyguard.Policy

  alias TdCore.Auth.Permissions
  alias TdQx.QualityControls.QualityControl

  # Admin accounts can do anything with data sets
  def authorize(_action, %{role: "admin"}, _params), do: true

  def authorize(:search, %{} = claims, _params),
    do: Permissions.authorized?(claims, :view_quality_controls)

  def authorize(:create, %{} = claims, {domain_ids, "published"}),
    do: Permissions.all_authorized?(claims, :publish_quality_controls, domain_ids)

  def authorize(:create, %{} = claims, {domain_ids, _}),
    do: Permissions.all_authorized?(claims, :create_quality_controls, domain_ids)

  def authorize(
        :create_draft,
        %{} = claims,
        {%QualityControl{domain_ids: domain_ids}, "published"}
      ),
      do: Permissions.all_authorized?(claims, :publish_quality_controls, domain_ids)

  def authorize(:create_draft, %{} = claims, {%QualityControl{domain_ids: domain_ids}, _}),
    do: Permissions.all_authorized?(claims, :create_quality_controls, domain_ids)

  def authorize(:update_draft, %{} = claims, %QualityControl{domain_ids: domain_ids}),
    do: Permissions.all_authorized?(claims, :create_quality_controls, domain_ids)

  def authorize(:show, %{} = claims, %QualityControl{domain_ids: domain_ids}),
    do: Permissions.authorized?(claims, :view_quality_controls, domain_ids)

  def authorize(action, %{} = claims, %QualityControl{domain_ids: domain_ids})
      when action in [
             "send_to_approval",
             "send_to_draft",
             "edit",
             "create_draft"
           ],
      do: Permissions.all_authorized?(claims, :create_quality_controls, domain_ids)

  def authorize(action, %{} = claims, %QualityControl{domain_ids: domain_ids})
      when action in [
             "reject",
             "publish",
             "restore"
           ],
      do: Permissions.all_authorized?(claims, :publish_quality_controls, domain_ids)

  def authorize("deprecate", %{} = claims, %QualityControl{domain_ids: domain_ids}),
    do: Permissions.all_authorized?(claims, :deprecate_quality_controls, domain_ids)

  # No other users can do nothing
  def authorize(_action, _claims, _params), do: false
end
