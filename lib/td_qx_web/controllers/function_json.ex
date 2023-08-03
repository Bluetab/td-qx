defmodule TdQxWeb.FunctionJSON do
  alias TdQx.Functions.Function
  alias TdQxWeb.ExpressionJSON
  alias TdQxWeb.ParamJSON

  @doc """
  Renders a list of functions.
  """
  def index(%{functions: functions}) do
    %{data: for(function <- functions, do: data(function))}
  end

  @doc """
  Renders a single function.
  """
  def show(%{function: function}) do
    %{data: data(function)}
  end

  defp data(%Function{} = function) do
    %{
      id: function.id,
      name: function.name,
      type: function.type,
      operator: function.operator,
      description: function.description,
      params: ParamJSON.embed_many(function),
      expression: ExpressionJSON.embed_one(function)
    }
  end
end

defmodule TdQxWeb.ExpressionJSON do
  alias TdQx.Functions.Expression
  alias TdQx.Functions.Function

  def embed_one(%Function{expression: %Expression{} = expression}), do: data(expression)
  def embed_one(_), do: nil

  defp data(%Expression{} = expression) do
    %{
      shape: expression.shape,
      value: expression.value
    }
  end
end

defmodule TdQxWeb.ParamJSON do
  alias TdQx.Functions.Function
  alias TdQx.Functions.Param

  def embed_many(%Function{params: [%Param{} | _] = params}),
    do: for(param <- params, do: data(param))

  def embed_many(_), do: []

  def data(%Param{} = param) do
    %{
      name: param.name,
      type: param.type,
      description: param.description
    }
  end
end
