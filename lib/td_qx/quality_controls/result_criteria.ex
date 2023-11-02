defmodule TdQx.QualityControls.ResultCriteria do
  @moduledoc """
  Ecto Schema module for QualityControl ResultCriteria
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdQx.QualityControls.ResultCriterias.Deviation
  alias TdQx.QualityControls.ResultCriterias.ErrorsNumber
  alias TdQx.QualityControls.ResultCriterias.Percentage

  @primary_key false
  embedded_schema do
    embeds_one(:deviation, Deviation, on_replace: :delete)
    embeds_one(:errors_number, ErrorsNumber, on_replace: :delete)
    embeds_one(:percentage, Percentage, on_replace: :delete)
  end

  def changeset(%__MODULE__{} = struct, %{} = params, type) do
    prop_params = %{type => params}

    struct
    |> cast(prop_params, [])
    |> cast_result_criteria_embed(type)
  end

  defp cast_result_criteria_embed(changeset, "deviation"),
    do: cast_embed(changeset, :deviation, with: &Deviation.changeset/2)

  defp cast_result_criteria_embed(changeset, "errors_number"),
    do: cast_embed(changeset, :errors_number, with: &ErrorsNumber.changeset/2)

  defp cast_result_criteria_embed(changeset, "percentage"),
    do: cast_embed(changeset, :percentage, with: &Percentage.changeset/2)

  defp cast_result_criteria_embed(changeset, _),
    do: add_error(changeset, :result_type, "invalid")
end
