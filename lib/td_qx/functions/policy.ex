defmodule TdQx.Functions.Policy do
  @moduledoc "Authorization rules for TdQx.Functions"

  @behaviour Bodyguard.Policy

  alias TdCore.Auth.Permissions

  # Admin accounts can do anything with data sets
  def authorize(_action, %{role: "admin"}, _params), do: true

  def authorize(:view, %{} = claims, _params),
    do: Permissions.authorized?(claims, :view_quality_controls)

  # Admin accounts can do anything with functions
  def authorize(_action, %{role: "admin"}, _params), do: true

  # No other users can do nothing
  def authorize(_action, _claims, _params), do: false
end
