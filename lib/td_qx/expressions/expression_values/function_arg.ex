defmodule TdQx.Expressions.ExpressionValues.FunctionArg do
  @moduledoc """
  Ecto Schema module for Arg of Function ExpressionValue
  """

  use Ecto.Schema

  alias TdQx.Expressions.Expression

  import Ecto.Changeset

  @primary_key false
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
end
