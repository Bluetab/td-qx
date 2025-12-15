defmodule TdQx.Expressions.ExpressionValues.FunctionArg do
  @moduledoc """
  Ecto Schema module for Arg of Function ExpressionValue
  """

  use Ecto.Schema

  alias TdQx.Expressions.Expression

  import Ecto.Changeset

  @primary_key false
  @derive Jason.Encoder
  embedded_schema do
    field :name, :string
    embeds_one(:expression, Expression, on_replace: :delete)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:name])
    |> cast_embed(:expression, with: &Expression.changeset/2)
    |> validate_required([:name])
  end

  def to_json([%__MODULE__{} | _] = args) do
    args
    |> Enum.map(fn %{name: name, expression: expression} ->
      {name, Expression.to_json(expression)}
    end)
    |> Enum.into(%{})
  end

  def to_json(_), do: nil
end
