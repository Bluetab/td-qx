defmodule TdQx.TestOperators do
  @moduledoc """
  Equality operators for tests
  """

  alias TdQx.QualityControls.QualityControl
  alias TdQx.QualityControls.QualityControlVersion

  def a <~> b, do: approximately_equal(a, b)
  def a ||| b, do: approximately_equal(sorted(a), sorted(b))

  ## Sort by id if present
  defp sorted([%{id: _} | _] = list) do
    Enum.sort_by(list, & &1.id)
  end

  defp sorted([%{"id" => _} | _] = list) do
    Enum.sort_by(list, &Map.get(&1, "id"))
  end

  defp sorted(list), do: Enum.sort(list)

  ## Equality test for data structures without comparing Ecto associations.
  defp approximately_equal(%QualityControlVersion{} = a, %QualityControlVersion{} = b) do
    drop_fields = [:quality_control]

    Map.drop(a, drop_fields) == Map.drop(b, drop_fields)
  end

  ## Equality test for data structures without comparing Ecto associations.
  defp approximately_equal(%QualityControl{} = a, %QualityControl{} = b) do
    drop_fields = [:published_version]

    Map.drop(a, drop_fields) == Map.drop(b, drop_fields)
  end

  defp approximately_equal([h | t], [h2 | t2]) do
    approximately_equal(h, h2) && approximately_equal(t, t2)
  end

  defp approximately_equal(%{"id" => id1}, %{"id" => id2}), do: id1 == id2

  defp approximately_equal(a, b), do: a == b
end
