defmodule TdQx.Scores.ScoreContents.Ratio do
  @moduledoc """
  Ecto Schema module for Score Content Ratio
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  @derive Jason.Encoder
  embedded_schema do
    field :total_count, :integer
    field :validation_count, :integer
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:total_count, :validation_count])
    |> validate_required([:total_count, :validation_count])
  end

  def to_json(%__MODULE__{} = ratio) do
    %{
      total_count: ratio.total_count,
      validation_count: ratio.validation_count
    }
  end

  def to_json(_), do: nil
end
