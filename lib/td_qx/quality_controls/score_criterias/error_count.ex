defmodule TdQx.QualityControls.ScoreCriterias.ErrorCount do
  @moduledoc """
  Ecto Schema module for QualityControl ScoreCriteria ErrorCount
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:goal, :float)
    field(:maximum, :float)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    changeset = cast(struct, params, [:goal, :maximum])

    goal = get_field(changeset, :goal)

    changeset
    |> validate_number(:goal, greater_than_or_equal_to: 0)
    |> validate_number(:maximum, greater_than_or_equal_to: goal)
    |> validate_required([:goal, :maximum])
  end

  def to_json(%__MODULE__{} = error_count) do
    %{
      goal: error_count.goal,
      maximum: error_count.maximum
    }
  end

  def to_json(_), do: nil
end
