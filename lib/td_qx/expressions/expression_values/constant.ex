defmodule TdQx.Expressions.ExpressionValues.Constant do
  @moduledoc """
  Ecto Schema module for ExpressionValue of shape constant
  """

  use Ecto.Schema

  alias TdQx.Functions.Function

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :type, :string
    field :value, :string
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:type, :value])
    |> validate_required([:type, :value])
    |> Function.validate_type()
  end

  def to_json(%__MODULE__{} = constant) do
    %{
      type: constant.type,
      value: constant.value
    }
  end

  def to_json(_), do: nil
end
