defmodule TdQx.Executions.Policy do
  @moduledoc "Authorization rules for TdQx.Executions"

  @behaviour Bodyguard.Policy

  alias TdCore.Auth.Permissions

  alias TdQx.Executions.ExecutionGroup

  @actions [:index, :create, :show, :update, :execute, :view]

  # Admin accounts can do anything with data sets
  def authorize(_action, %{role: "admin"}, _params), do: true
  def authorize(_action, %{role: "service"}, _params), do: true

  def authorize(action, %{role: "user"} = claims, _params)
      when action in @actions,
      do: Permissions.authorized?(claims, :execute_quality_controls)

  # No other users can do nothing
  def authorize(_action, _claims, _params), do: false
end
