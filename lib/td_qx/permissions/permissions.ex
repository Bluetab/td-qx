defmodule TdQx.Permissions do
  @moduledoc """
  Performs permissions checks for the current user
  """
  alias TdCache.Permissions

  def visible_by_permissions?(_, %{role: "admin"} = _claims), do: true

  def visible_by_permissions?(%{domain_ids: domain_ids}, claims) do
    Enum.any?(domain_ids, fn domain ->
      authorized?(claims, :execute_quality_controls, domain)
    end)
  end

  def authorized?(%{jti: jti}, permission, domain_id) do
    Permissions.has_permission?(jti, permission, "domain", domain_id)
  end
end
