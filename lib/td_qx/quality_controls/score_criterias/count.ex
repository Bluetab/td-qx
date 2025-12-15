defmodule TdQx.QualityControls.ScoreCriterias.Count do
  @moduledoc """
  Ecto Schema module for QualityControl ScoreCriteria Count
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  @derive Jason.Encoder
  embedded_schema do
    field :goal, :integer
    field :maximum, :integer
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    changeset = cast(struct, params, [:goal, :maximum])

    goal = get_field(changeset, :goal)

    struct
    |> cast(params, [:goal, :maximum])
    |> validate_number(:goal, greater_than_or_equal_to: 0)
    |> validate_number(:maximum, greater_than_or_equal_to: goal)
    |> validate_required([:goal, :maximum])
  end

  def to_json(%__MODULE__{} = count) do
    %{
      goal: count.goal,
      maximum: count.maximum
    }
  end

  def to_json(_), do: nil
end
