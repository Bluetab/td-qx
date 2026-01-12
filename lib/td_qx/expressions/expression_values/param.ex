defmodule TdQx.Expressions.ExpressionValues.Param do
  @moduledoc """
  Ecto Schema module for ExpressionValue of shape param
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  @derive Jason.Encoder
  embedded_schema do
    field :id, :integer
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:id])
    |> validate_required([:id])
  end

  def to_json(%__MODULE__{} = param) do
    %{id: param.id}
  end

  def to_json(_), do: nil
end
