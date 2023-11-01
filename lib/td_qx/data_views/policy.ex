defmodule TdQx.DataViews.Policy do
  @moduledoc "Authorization rules for TdQx.DataViews"

  @behaviour Bodyguard.Policy

  alias TdCore.Auth.Permissions

  # Admin accounts can do anything with data sets
  def authorize(_action, %{role: "admin"}, _params), do: true

  def authorize(:view, %{} = claims, _params),
    do: Permissions.authorized?(claims, :view_quality_controls)

  # No other users can do nothing
  def authorize(_action, _claims, _params), do: false
end
