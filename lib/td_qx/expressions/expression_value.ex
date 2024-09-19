defmodule TdQx.Expressions.ExpressionValue do
  @moduledoc """
  Ecto Schema module for Expression
  """

  use Ecto.Schema

  alias TdQx.Expressions.ExpressionValue
  alias TdQx.Expressions.ExpressionValues.Constant
  alias TdQx.Expressions.ExpressionValues.Field
  alias TdQx.Expressions.ExpressionValues.Function
  alias TdQx.Expressions.ExpressionValues.Param

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    embeds_one(:constant, Constant, on_replace: :delete)
    embeds_one(:field, Field, on_replace: :delete)
    embeds_one(:function, Function, on_replace: :delete)
    embeds_one(:param, Param, on_replace: :delete)
  end

  def changeset(%__MODULE__{} = struct, %{} = params, value_mode) do
    shape = shape_for_value_mode(value_mode)
    prop_params = %{shape => params}

    struct
    |> cast(prop_params, [])
    |> cast_expression_value_embed(value_mode)
  end

  def unfold(%ExpressionValue{constant: %Constant{value: value, type: type}}) do
    %{__type__: "constant", type: type, value: value}
  end

  def unfold(%ExpressionValue{field: %Field{id: id, name: name, parent_id: parent_id}}) do
    %{__type__: "field", id: id, name: name, parent_id: parent_id}
  end

  def unfold(%ExpressionValue{param: %Param{id: id}}, params_context) do
    Map.get(params_context, id)
  end

  def unfold(%ExpressionValue{function: function}, params_context) do
    Function.unfold(function, params_context)
  end

  defp shape_for_value_mode("aggregate_function"), do: "function"
  defp shape_for_value_mode(shape), do: shape

  defp cast_expression_value_embed(changeset, "constant"),
    do: cast_embed(changeset, :constant, with: &Constant.changeset/2)

  defp cast_expression_value_embed(changeset, "field"),
    do: cast_embed(changeset, :field, with: &Field.changeset/2)

  defp cast_expression_value_embed(changeset, "function"),
    do: cast_embed(changeset, :function, with: &Function.changeset/2)

  defp cast_expression_value_embed(changeset, "aggregate_function"),
    do: cast_embed(changeset, :function, with: &Function.changeset(&1, &2, "aggregator"))

  defp cast_expression_value_embed(changeset, "param"),
    do: cast_embed(changeset, :param, with: &Param.changeset/2)

  defp cast_expression_value_embed(changeset, _),
    do: add_error(changeset, :shape, "invalid")
end
