defmodule TdQx.Expressions.Clause do
  @moduledoc """
  Ecto Schema module for a Clause
  """

  use Ecto.Schema

  alias TdQx.Expressions.Expression

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    embeds_many(:expressions, Expression, on_replace: :delete)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [])
    |> cast_embed(:expressions, with: &Expression.changeset/2, required: true)
  end

  def unfold([%__MODULE__{} | _] = clauses) do
    Enum.map(clauses, &unfold/1)
  end

  def unfold([]), do: []

  def unfold(%__MODULE__{expressions: expressions}) do
    Enum.map(expressions, &Expression.unfold/1)
  end
end
