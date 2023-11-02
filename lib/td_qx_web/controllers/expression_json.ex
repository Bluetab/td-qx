defmodule TdQxWeb.ExpressionJSON do
  alias TdQx.Expressions.Clause
  alias TdQx.Expressions.Expression
  alias TdQx.Functions.Function
  alias TdQxWeb.ExpressionValueJSON

  def embed_one(%Function{expression: %Expression{} = expression}), do: data(expression)
  def embed_one(%Expression{} = expression), do: data(expression)
  def embed_one(_), do: nil

  def embed_many(%Clause{expressions: [%Expression{} | _] = clause}),
    do: for(expression <- clause, do: data(expression))

  def embed_many(_), do: nil

  defp data(%Expression{} = expression) do
    %{
      shape: expression.shape,
      value: ExpressionValueJSON.embed_one(expression)
    }
  end
end

defmodule TdQxWeb.ExpressionValueJSON do
  alias TdQx.Expressions.Expression
  alias TdQx.Expressions.ExpressionValue
  alias TdQxWeb.ExpressionValueConstantJSON
  alias TdQxWeb.ExpressionValueFieldJSON
  alias TdQxWeb.ExpressionValueFunctionJSON
  alias TdQxWeb.ExpressionValueParamJSON

  def embed_one(%Expression{value: %ExpressionValue{} = value, shape: shape}),
    do: data(shape, value)

  def embed_one(_), do: nil

  defp data("constant", %ExpressionValue{} = value),
    do: ExpressionValueConstantJSON.embed_one(value)

  defp data("field", %ExpressionValue{} = value),
    do: ExpressionValueFieldJSON.embed_one(value)

  defp data("function", %ExpressionValue{} = value),
    do: ExpressionValueFunctionJSON.embed_one(value)

  defp data("param", %ExpressionValue{} = value),
    do: ExpressionValueParamJSON.embed_one(value)

  defp data(_, %ExpressionValue{}), do: nil
end

defmodule TdQxWeb.ExpressionValueConstantJSON do
  alias TdQx.Expressions.ExpressionValue
  alias TdQx.Expressions.ExpressionValues.Constant

  def embed_one(%ExpressionValue{constant: %Constant{} = constant}), do: data(constant)
  def embed_one(_), do: nil

  defp data(%Constant{} = constant) do
    %{
      type: constant.type,
      value: constant.value
    }
  end
end

defmodule TdQxWeb.ExpressionValueFieldJSON do
  alias TdQx.Expressions.ExpressionValue
  alias TdQx.Expressions.ExpressionValues.Field

  def embed_one(%ExpressionValue{field: %Field{} = field}), do: data(field)
  def embed_one(_), do: nil

  defp data(%Field{} = field) do
    %{
      id: field.id,
      type: field.type,
      name: field.name,
      parent_id: field.parent_id
    }
  end
end

defmodule TdQxWeb.ExpressionValueFunctionJSON do
  alias TdQx.Expressions.ExpressionValue
  alias TdQx.Expressions.ExpressionValues.Function
  alias TdQxWeb.ExpressionValueFunctionArgJSON

  def embed_one(%ExpressionValue{function: %Function{} = function}), do: data(function)
  def embed_one(_), do: nil

  defp data(%Function{} = function) do
    %{
      type: function.type,
      name: function.name
    }
    |> maybe_with_args(function)
  end

  defp maybe_with_args(json, function) do
    case ExpressionValueFunctionArgJSON.embed_one(function) do
      nil -> json
      args -> Map.put(json, :args, args)
    end
  end
end

defmodule TdQxWeb.ExpressionValueFunctionArgJSON do
  alias TdQx.Expressions.ExpressionValue
  alias TdQx.Expressions.ExpressionValues.Function
  alias TdQx.Expressions.ExpressionValues.FunctionArg
  alias TdQxWeb.ExpressionJSON

  def embed_one(%Function{args: [%FunctionArg{} | _] = args}), do: data(args)
  def embed_one(_), do: nil

  defp data(args) do
    args
    |> Enum.map(fn %{name: name, expression: expression} ->
      {name, ExpressionJSON.embed_one(expression)}
    end)
    |> Enum.into(%{})
  end
end

defmodule TdQxWeb.ExpressionValueParamJSON do
  alias TdQx.Expressions.ExpressionValue
  alias TdQx.Expressions.ExpressionValues.Param

  def embed_one(%ExpressionValue{param: %Param{} = param}), do: data(param)
  def embed_one(_), do: nil

  defp data(%Param{} = param) do
    %{
      id: param.id
    }
  end
end

defmodule TdQxWeb.ClauseJSON do
  alias TdQx.Expressions.Clause
  alias TdQxWeb.ExpressionJSON

  def embed_many(%{clauses: [%Clause{} | _] = clauses}),
    do: for(clause <- clauses, do: data(clause))

  def embed_many([%Clause{} | _] = clauses),
    do: for(clause <- clauses, do: data(clause))

  def embed_many(_), do: nil

  defp data(%Clause{} = clause) do
    %{
      expressions: ExpressionJSON.embed_many(clause)
    }
  end
end
