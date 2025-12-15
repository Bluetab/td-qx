defmodule TdQx.Expressions.Expression do
  @moduledoc """
  Ecto Schema module for Expression
  """

  use Ecto.Schema

  alias TdQx.Expressions.ExpressionValue

  import Ecto.Changeset

  @valid_shapes ~w|constant function param field|

  @primary_key false
  @derive Jason.Encoder
  embedded_schema do
    field :shape, :string
    embeds_one(:value, ExpressionValue, on_replace: :delete)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    changeset = cast(struct, params, [:shape])

    shape = get_field(changeset, :shape)

    changeset
    |> cast_embed(:value, with: &ExpressionValue.changeset(&1, &2, shape), required: true)
    |> validate_required([:shape])
    |> validate_shape()
  end

  def changeset_for_aggregate(%__MODULE__{} = struct, %{} = params) do
    changeset = cast(struct, params, [:shape])

    case get_field(changeset, :shape) do
      "function" ->
        changeset
        |> cast_embed(:value,
          with: &ExpressionValue.changeset(&1, &2, "aggregate_function"),
          required: true
        )
        |> validate_required([:shape])
        |> validate_shape()

      _ ->
        add_error(changeset, :shape, "invalid shape for aggregated field")
    end
  end

  defp validate_shape(changeset), do: validate_inclusion(changeset, :shape, @valid_shapes)

  def type(%__MODULE__{shape: "constant", value: %{constant: %{type: type}}}), do: type
  def type(%__MODULE__{shape: "function", value: %{function: %{type: type}}}), do: type
  def type(%__MODULE__{shape: "param", value: _}), do: nil
  def type(%__MODULE__{shape: "field", value: %{field: %{type: type}}}), do: type
  def type(_), do: nil

  def to_json([%__MODULE__{} | _] = expressions),
    do: for(expression <- expressions, do: to_json(expression))

  def to_json([]), do: []

  def to_json(%__MODULE__{} = expression) do
    %{
      shape: expression.shape,
      value: ExpressionValue.to_json(expression.value)
    }
  end

  def to_json(_), do: nil

  def unfold(expression, params_context \\ %{})

  def unfold(%__MODULE__{shape: "constant", value: constant}, _),
    do: ExpressionValue.unfold(constant)

  def unfold(%__MODULE__{shape: "param", value: param}, params_context) do
    ExpressionValue.unfold(param, params_context)
  end

  def unfold(%__MODULE__{shape: "field", value: field}, _) do
    ExpressionValue.unfold(field)
  end

  def unfold(%__MODULE__{shape: "function", value: function}, params_context),
    do: ExpressionValue.unfold(function, params_context)

  def unfold(_, _) do
    {:error, :invalid_expression}
  end
end
