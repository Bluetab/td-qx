defmodule TdQx.Scores.ScoreContents.Count do
  @moduledoc """
  Ecto Schema module for Scores Content Count
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:count, :integer)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:count])
    |> validate_required([:count])
  end

  def to_json(%__MODULE__{} = count) do
    %{count: count.count}
  end

  def to_json(_), do: nil
end
