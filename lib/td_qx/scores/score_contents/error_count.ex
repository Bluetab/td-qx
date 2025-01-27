defmodule TdQx.Scores.ScoreContents.ErrorCount do
  @moduledoc """
  Ecto Schema module for Scores Content ErrorCount
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :error_count, :integer
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:error_count])
    |> validate_required([:error_count])
  end

  def to_json(%__MODULE__{} = error_count) do
    %{error_count: error_count.error_count}
  end

  def to_json(_), do: nil
end
