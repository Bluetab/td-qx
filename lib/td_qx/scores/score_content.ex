defmodule TdQx.Scores.ScoreContent do
  @moduledoc """
  Ecto Schema module for Scores Contents
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdQx.Scores.ScoreContents.ErrorCount
  alias TdQx.Scores.ScoreContents.Ratio

  @primary_key false
  embedded_schema do
    embeds_one(:error_count, ErrorCount, on_replace: :delete)
    embeds_one(:ratio, Ratio, on_replace: :delete)
  end

  def changeset(%__MODULE__{} = struct, %{} = params, type) do
    prop_params = %{type => params}

    struct
    |> cast(prop_params, [])
    |> cast_score_content_embed(type)
  end

  def to_json(%__MODULE__{error_count: %ErrorCount{} = error_count}),
    do: ErrorCount.to_json(error_count)

  def to_json(%__MODULE__{ratio: %Ratio{} = ratio}),
    do: Ratio.to_json(ratio)

  def to_json(_), do: nil

  def from_result(params, type) do
    {%{}, %{result: :map}}
    |> cast(params, [:result])
    |> get_change(:result)
    |> parse_result(type)
  end

  defp parse_result(
         %{"total_count" => [[total_count]], "validation_count" => [[validation_count]]},
         "ratio"
       ),
       do: %{
         "total_count" => total_count,
         "validation_count" => validation_count
       }

  defp parse_result(%{"error_count" => [[error_count]]}, "error_count"),
    do: %{
      "error_count" => error_count
    }

  defp parse_result(_, _), do: nil

  defp cast_score_content_embed(changeset, "ratio"),
    do: cast_embed(changeset, :ratio, with: &Ratio.changeset/2)

  defp cast_score_content_embed(changeset, "error_count"),
    do: cast_embed(changeset, :error_count, with: &ErrorCount.changeset/2)

  defp cast_score_content_embed(changeset, _),
    do: add_error(changeset, :score_type, "invalid")
end
