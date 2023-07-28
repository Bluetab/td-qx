defmodule TdQx.Functions.Policy do
  @moduledoc "Authorization rules for TdQx.Functions"

  @behaviour Bodyguard.Policy

  # Admin accounts can do anything with functions
  def authorize(_action, %{role: "admin"}, _params), do: true

  # No other users can do nothing
  def authorize(_action, _claims, _params), do: false
end
