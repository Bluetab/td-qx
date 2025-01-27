defmodule TdQx.QualityControls.ScoreCriterias.Percentage do
  @moduledoc """
  Ecto Schema module for QualityControl ScoreCriteria Percentage
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :goal, :float
    field :minimum, :float
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    changeset = cast(struct, params, [:goal, :minimum])

    goal = get_field(changeset, :goal)

    changeset
    |> validate_number(:goal, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:minimum, greater_than_or_equal_to: 0, less_than_or_equal_to: goal)
    |> validate_required([:goal, :minimum])
  end

  def to_json(%__MODULE__{} = percentage) do
    %{
      goal: percentage.goal,
      minimum: percentage.minimum
    }
  end

  def to_json(_), do: nil
end
