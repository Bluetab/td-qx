defmodule TdQx.Scores.Policy do
  @moduledoc "Authorization rules for TdQx.Scores"

  @behaviour Bodyguard.Policy

  alias TdCore.Auth.Permissions
  alias TdQx.QualityControls.QualityControl
  alias TdQx.Scores.ScoreGroup

  # Admin accounts can do anything with data sets
  def authorize(_action, %{role: role}, _params) when role in ["admin", "service"], do: true

  def authorize(action, %{role: "user"}, _params)
      when action in [
             :fetch_pending,
             :success,
             :fail
           ],
      do: false

  def authorize(action, %{role: "user"} = claims, ScoreGroup)
      when action in [:index, :create, :execute],
      do: Permissions.authorized?(claims, :execute_quality_controls)

  def authorize(:index, %{} = claims, %QualityControl{domain_ids: domain_ids}),
    do: Permissions.all_authorized?(claims, :view_quality_controls, domain_ids)

  def authorize(:show, %{user_id: user_id}, %ScoreGroup{created_by: created_by}),
    do: user_id == created_by

  def authorize(_, %{} = claims, %QualityControl{domain_ids: domain_ids}),
    do: Permissions.all_authorized?(claims, :manage_quality_controls, domain_ids)

  # No other users can do nothing
  def authorize(_action, _claims, _params), do: false
end
