defmodule TdQx.Functions.Function do
  @moduledoc """
  Ecto Schema module for Function
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias TdQx.Expressions.Expression
  alias TdQx.Functions.Param

  @valid_types ~w|boolean string number date timestamp any|

  schema "functions" do
    field(:name, :string)
    field(:type, :string)
    field(:class, :string)
    field(:operator, :string)
    field(:description, :string)
    embeds_many(:params, Param, on_replace: :delete)
    embeds_one(:expression, Expression, on_replace: :delete)

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(function, attrs) do
    function
    |> cast(attrs, [:name, :type, :class, :operator, :description])
    |> cast_embed(:params, with: &Param.changeset/2)
    |> cast_embed(:expression, with: &Expression.changeset/2)
    |> validate_required([:name, :type])
    |> validate_type()
    |> unique_constraint([:name, :type])
  end

  def validate_type(changeset) do
    validate_inclusion(changeset, :type, @valid_types)
  end
end
