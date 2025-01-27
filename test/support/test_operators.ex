defmodule TdQx.TestOperators do
  @moduledoc """
  Equality operators for tests
  """

  alias TdQx.QualityControls.QualityControl
  alias TdQx.QualityControls.QualityControlVersion
  alias TdQx.Scores.Score
  alias TdQx.Scores.ScoreEvent
  alias TdQx.Scores.ScoreGroup

  def a <~> b, do: approximately_equal(a, b)
  def a ||| b, do: approximately_equal(sorted(a), sorted(b))

  ## Sort by id if present
  defp sorted([%{id: _} | _] = list) do
    Enum.sort_by(list, & &1.id)
  end

  defp sorted([%{"id" => _, "version" => _} | _] = list) do
    Enum.sort_by(list, &Map.take(&1, ["id", "version"]))
  end

  defp sorted([%{"version" => _} | _] = list) do
    Enum.sort_by(list, &Map.get(&1, "version"))
  end

  defp sorted([%{"id" => _} | _] = list) do
    Enum.sort_by(list, &Map.get(&1, "id"))
  end

  defp sorted(list), do: Enum.sort(list)

  defp approximately_equal(%QualityControlVersion{} = a, %QualityControlVersion{} = b) do
    drop_fields = [:quality_control]

    Map.drop(a, drop_fields) == Map.drop(b, drop_fields)
  end

  defp approximately_equal(%QualityControl{} = a, %QualityControl{} = b) do
    drop_fields = [:published_version]

    Map.drop(a, drop_fields) == Map.drop(b, drop_fields)
  end

  defp approximately_equal(%ScoreGroup{} = a, %ScoreGroup{} = b) do
    drop_fields = [:scores]
    Map.drop(a, drop_fields) == Map.drop(b, drop_fields)
  end

  defp approximately_equal(%Score{} = a, %Score{} = b) do
    drop_fields = [:group, :quality_control_version, :status, :events]
    Map.drop(a, drop_fields) == Map.drop(b, drop_fields)
  end

  defp approximately_equal(%ScoreEvent{} = a, %ScoreEvent{} = b) do
    drop_fields = [:score]
    Map.drop(a, drop_fields) == Map.drop(b, drop_fields)
  end

  defp approximately_equal([h | t], [h2 | t2]) do
    approximately_equal(h, h2) && approximately_equal(t, t2)
  end

  defp approximately_equal(%{"id" => id1}, %{"id" => id2}), do: id1 == id2

  defp approximately_equal(a, b), do: a == b
end
