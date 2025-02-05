defmodule TdQx.DataViews.QueryableProperties.SelectField do
  @moduledoc """
  Ecto Schema module for DataViews QueryablesProperties SelectField
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdQx.Expressions.Expression

  @primary_key false
  embedded_schema do
    field(:id, :integer)
    field(:alias, :string)
    embeds_one(:expression, Expression, on_replace: :delete)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:alias, :id])
    |> cast_embed(:expression, with: &Expression.changeset/2, required: true)
    |> validate_required([:alias, :id])
  end

  def changeset_for_aggregate(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:alias, :id])
    |> cast_embed(:expression, with: &Expression.changeset_for_aggregate/2, required: true)
    |> validate_required([:alias, :id])
  end

  def to_json([%__MODULE__{} | _] = select_fields),
    do: for(select_field <- select_fields, do: to_json(select_field))

  def to_json([]), do: []

  def to_json(%__MODULE__{} = field) do
    %{
      id: field.id,
      alias: field.alias,
      expression: Expression.to_json(field.expression)
    }
  end

  def to_json(_), do: nil

  def unfold([%__MODULE__{} | _] = fields) do
    Enum.map(fields, &unfold/1)
  end

  def unfold([]), do: []

  def unfold(%__MODULE__{alias: field_alias, expression: expression}) do
    %{__type__: "select_field", alias: field_alias, expression: Expression.unfold(expression)}
  end
end
