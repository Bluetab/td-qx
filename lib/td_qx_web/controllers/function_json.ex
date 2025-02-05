defmodule TdQxWeb.FunctionJSON do
  alias TdQx.Expressions.Expression
  alias TdQx.Functions.Function
  alias TdQx.Functions.Param

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
      class: function.class,
      operator: function.operator,
      description: function.description,
      params: Param.to_json(function.params),
      expression: Expression.to_json(function.expression)
    }
  end
end
