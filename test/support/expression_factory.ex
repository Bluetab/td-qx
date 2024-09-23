defmodule TdQx.ExpressionFactory do
  @moduledoc """
  Factory for expression resources.
  """
  import TdQx.Factory

  def function(value \\ []) do
    build(:expression,
      shape: "function",
      value:
        build(:expression_value,
          function: build(:ev_function, value)
        )
    )
  end

  def param(id) do
    build(:expression,
      shape: "param",
      value:
        build(:expression_value,
          param: build(:ev_param, id: id)
        )
    )
  end

  def function_arg(name, expression) do
    build(:ev_function_arg,
      name: name,
      expression: expression
    )
  end

  def constant(type, value),
    do:
      build(:expression,
        shape: "constant",
        value:
          build(:expression_value,
            constant:
              build(:ev_constant,
                type: type,
                value: value
              )
          )
      )

  def field(values \\ []) do
    build(:expression,
      shape: "field",
      value: build(:expression_value, field: build(:ev_field, values))
    )
  end
end
