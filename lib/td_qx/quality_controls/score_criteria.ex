defmodule TdQx.QualityControls.ScoreCriteria do
  @moduledoc """
  Ecto Schema module for QualityControl ScoreCriteria
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdQx.QualityControls.ScoreCriterias.Count
  alias TdQx.QualityControls.ScoreCriterias.Deviation
  alias TdQx.QualityControls.ScoreCriterias.ErrorCount
  alias TdQx.QualityControls.ScoreCriterias.Percentage

  @primary_key false
  @derive Jason.Encoder
  embedded_schema do
    embeds_one :deviation, Deviation, on_replace: :delete
    embeds_one :count, Count, on_replace: :delete
    embeds_one :percentage, Percentage, on_replace: :delete
    embeds_one :error_count, ErrorCount, on_replace: :delete
  end

  def changeset(%__MODULE__{} = struct, %{} = params, control_mode) do
    prop_params = %{control_mode => params}

    struct
    |> cast(prop_params, [])
    |> cast_score_criteria_embed(control_mode)
  end

  def to_json(%__MODULE__{count: %Count{} = count}),
    do: Count.to_json(count)

  def to_json(%__MODULE__{deviation: %Deviation{} = deviation}),
    do: Deviation.to_json(deviation)

  def to_json(%__MODULE__{percentage: %Percentage{} = percentage}),
    do: Percentage.to_json(percentage)

  def to_json(%__MODULE__{error_count: %ErrorCount{} = error_count}),
    do: ErrorCount.to_json(error_count)

  def to_json(_), do: nil

  defp cast_score_criteria_embed(changeset, "deviation"),
    do: cast_embed(changeset, :deviation, with: &Deviation.changeset/2)

  defp cast_score_criteria_embed(changeset, "count"),
    do: cast_embed(changeset, :count, with: &Count.changeset/2)

  defp cast_score_criteria_embed(changeset, "percentage"),
    do: cast_embed(changeset, :percentage, with: &Percentage.changeset/2)

  defp cast_score_criteria_embed(changeset, "error_count"),
    do: cast_embed(changeset, :error_count, with: &ErrorCount.changeset/2)

  defp cast_score_criteria_embed(changeset, _),
    do: add_error(changeset, :control_mode, "invalid")
end
