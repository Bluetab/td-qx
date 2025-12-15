defmodule TdQx.Audit.Message do
  @moduledoc """
  Helper module for applying metadata to audit payloads.
  """

  alias Ecto.Changeset

  def apply_metadata(payload, metadata, _base_fields) when map_size(metadata) == 0 do
    payload
  end

  def apply_metadata(payload, metadata, base_fields) do
    metadata =
      Map.new(metadata, fn
        {:changes, value} ->
          value =
            value
            |> Map.take(base_fields)
            |> diff()

          {:changes, value}

        {key, value} ->
          {key, value}
      end)

    Map.merge(payload, metadata)
  end

  def diff(%Changeset{} = cs) do
    traverse_changes(cs.changes)
  end

  def diff(%{} = changes) do
    traverse_changes(changes)
  end

  defp traverse_changes(changes) do
    Enum.reduce(changes, %{}, fn
      {field, %Changeset{} = nested}, acc ->
        Map.put(acc, field, traverse_changes(nested.changes))

      {field, list}, acc when is_list(list) ->
        Map.put(acc, field, Enum.map(list, &unwrap_list_item/1))

      {field, value}, acc ->
        Map.put(acc, field, value)
    end)
  end

  defp unwrap_list_item(%Changeset{} = cs), do: traverse_changes(cs.changes)

  defp unwrap_list_item(%{changes: changes}),
    do: traverse_changes(changes)

  defp unwrap_list_item(%{} = map), do: map
  defp unwrap_list_item(value), do: value
end
