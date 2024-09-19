defmodule TdQx.Expressions.ExpressionTest do
  use TdQx.DataCase

  alias Ecto.Changeset
  alias TdQx.ExpressionFactory
  alias TdQx.Expressions.Expression
  alias TdQxWeb.ChangesetJSON

  describe "expression changeset" do
    test "changeset/2 validates shape" do
      expression_attrs = %{
        shape: "invalid_shape",
        value: %{}
      }

      assert %{
               valid?: false,
               errors: [
                 shape: {"is invalid", [validation: :inclusion, enum: _]}
               ]
             } = Expression.changeset(%Expression{}, expression_attrs)
    end

    test "changeset/2 validates constant shape value" do
      expression_attrs = %{
        shape: "constant",
        value: %{
          type: "invalid_type"
        }
      }

      assert %{valid?: false} = changeset = Expression.changeset(%Expression{}, expression_attrs)

      %{errors: errors} = ChangesetJSON.error(%{changeset: changeset})

      assert %{
               value: %{constant: %{type: ["is invalid"], value: ["can't be blank"]}}
             } = errors
    end

    test "changeset/2 creates valid shape constant" do
      expression_attrs = %{
        shape: "constant",
        value: %{
          type: "boolean",
          value: "true"
        }
      }

      assert %{
               valid?: true,
               changes: %{shape: "constant"}
             } = Expression.changeset(%Expression{}, expression_attrs)
    end

    test "changeset/2 validates field shape value" do
      expression_attrs = %{
        shape: "field",
        value: %{
          type: "invalid_type"
        }
      }

      assert %{valid?: false} = changeset = Expression.changeset(%Expression{}, expression_attrs)

      %{errors: errors} = ChangesetJSON.error(%{changeset: changeset})

      assert %{
               value: %{
                 field: %{
                   parent_id: ["can't be blank"],
                   name: ["can't be blank"],
                   type: ["is invalid"]
                 }
               }
             } = errors
    end

    test "changeset/2 creates valid shape field" do
      expression_attrs = %{
        shape: "field",
        value: %{
          id: 1,
          type: "boolean",
          name: "field1",
          parent_id: 0
        }
      }

      assert %{
               valid?: true,
               changes: %{shape: "field"}
             } = Expression.changeset(%Expression{}, expression_attrs)
    end

    test "changeset/2 validates param shape value" do
      expression_attrs = %{
        shape: "param",
        value: %{
          id: nil
        }
      }

      assert %{valid?: false} = changeset = Expression.changeset(%Expression{}, expression_attrs)

      %{errors: errors} = ChangesetJSON.error(%{changeset: changeset})

      assert %{
               value: %{param: %{id: ["can't be blank"]}}
             } = errors
    end

    test "changeset/2 creates valid shape param" do
      expression_attrs = %{
        shape: "param",
        value: %{
          id: 1
        }
      }

      assert %{
               valid?: true,
               changes: %{shape: "param"}
             } = Expression.changeset(%Expression{}, expression_attrs)
    end
  end

  describe "expression changeset/2 for shape function" do
    test "validates value type" do
      expression_attrs = %{
        shape: "function",
        value: %{
          type: "invalid_type"
        }
      }

      assert %{valid?: false} = changeset = Expression.changeset(%Expression{}, expression_attrs)

      %{errors: errors} = ChangesetJSON.error(%{changeset: changeset})

      assert %{
               value: %{
                 function: %{
                   name: ["can't be blank"],
                   type: ["is invalid"],
                   function: ["function does not exist"]
                 }
               }
             } = errors
    end

    test "valid expression" do
      insert(:function, name: "func1", type: "boolean")

      expression_attrs = %{
        shape: "function",
        value: %{
          type: "boolean",
          name: "func1",
          args: %{}
        }
      }

      assert %{
               valid?: true,
               changes: %{shape: "function"}
             } = Expression.changeset(%Expression{}, expression_attrs)
    end

    test "validates function exists" do
      expression_attrs = %{
        shape: "function",
        value: %{
          type: "boolean",
          name: "func1",
          args: %{}
        }
      }

      assert %{valid?: false} = changeset = Expression.changeset(%Expression{}, expression_attrs)

      %{errors: errors} = ChangesetJSON.error(%{changeset: changeset})

      assert %{value: %{function: %{function: ["function does not exist"]}}} = errors
    end

    test "validates function args" do
      insert(:function,
        name: "func1",
        type: "boolean",
        params: [
          build(:function_param, name: "param1", type: "boolean"),
          build(:function_param, name: "param2", type: "string")
        ]
      )

      expression_attrs = %{
        shape: "function",
        value: %{
          type: "boolean",
          name: "func1",
          args: %{
            param1: %{shape: "constant", value: %{type: "boolean", value: "true"}},
            param2: %{shape: "constant", value: %{type: "string", value: "foobar"}},
            param3: %{shape: "constant", value: %{type: "string", value: "not casted"}}
          }
        }
      }

      assert %{valid?: true} = changeset = Expression.changeset(%Expression{}, expression_attrs)

      {:ok,
       %{shape: "function", value: %{function: %{type: "boolean", name: "func1", args: args}}}} =
        Changeset.apply_action(changeset, :insert)

      refute Enum.any?(args, &(&1.name == "param3"))
    end

    test "validates function args expression shape" do
      insert(:function,
        name: "func1",
        type: "boolean",
        params: [
          build(:function_param, name: "param1", type: "boolean")
        ]
      )

      expression_attrs = %{
        shape: "function",
        value: %{
          type: "boolean",
          name: "func1",
          args: %{
            param1: %{shape: "invalid_shape", value: %{type: "boolean", value: "true"}}
          }
        }
      }

      assert %{valid?: false} = changeset = Expression.changeset(%Expression{}, expression_attrs)

      %{errors: errors} = ChangesetJSON.error(%{changeset: changeset})

      assert %{
               value: %{
                 function: %{
                   args: [%{expression: %{shape: ["is invalid"], value: %{shape: ["invalid"]}}}]
                 }
               }
             } = errors
    end
  end

  describe "Expression.unfold/2" do
    test "unfolds a constant expression" do
      type = "string"
      value = "foo"

      expression = ExpressionFactory.constant(type, value)

      assert Expression.unfold(expression) == %{
               __type__: "constant",
               type: type,
               value: value
             }
    end

    test "unfolds a native function expression" do
      function_type = "boolean"
      function_name = "empty_string"

      insert(:function,
        type: function_type,
        name: function_name,
        params: [
          build(:function_param, name: "text", type: "string")
        ],
        expression: nil
      )

      expression =
        ExpressionFactory.function(
          type: function_type,
          name: function_name,
          args: [
            ExpressionFactory.function_arg("text", ExpressionFactory.constant("string", "foo"))
          ]
        )

      assert Expression.unfold(expression) == %{
               __type__: "function",
               type: function_type,
               name: function_name,
               args: [
                 %{
                   __type__: "function_arg",
                   name: "text",
                   expression: %{__type__: "constant", type: "string", value: "foo"}
                 }
               ]
             }
    end

    test "unfolds handles unmatching function params and args" do
      insert(:function,
        type: "boolean",
        name: "empty_string",
        params: [
          build(:function_param, name: "text", type: "string")
        ],
        expression: nil
      )

      expression =
        ExpressionFactory.function(
          type: "boolean",
          name: "empty_string",
          args: [
            ExpressionFactory.function_arg(
              "invalid_arg",
              ExpressionFactory.constant("string", "foo")
            )
          ]
        )

      assert Expression.unfold(expression) == %{
               __type__: "function",
               type: "boolean",
               name: "empty_string",
               args: [
                 %{
                   __type__: "function_arg",
                   name: "text",
                   expression: {:error, :invalid_expression}
                 }
               ]
             }
    end

    test "unfolds a user function expression" do
      insert(:function,
        type: "string",
        name: "identity",
        params: [
          build(:function_param, id: 0, name: "value", type: "string")
        ],
        expression: ExpressionFactory.param(0)
      )

      expression =
        ExpressionFactory.function(
          type: "string",
          name: "identity",
          args: [
            ExpressionFactory.function_arg("value", ExpressionFactory.constant("string", "foo"))
          ]
        )

      assert Expression.unfold(expression) == %{
               __type__: "constant",
               type: "string",
               value: "foo"
             }
    end

    test "unfolds a nested user function expression" do
      insert(:function,
        type: "boolean",
        name: "eq",
        params: [
          build(:function_param, id: 0, name: "arg1", type: "string"),
          build(:function_param, id: 1, name: "arg2", type: "string")
        ],
        expression: nil
      )

      insert(:function,
        type: "boolean",
        name: "eq_to_foo",
        params: [
          build(:function_param, id: 0, name: "value", type: "string")
        ],
        expression:
          ExpressionFactory.function(
            type: "boolean",
            name: "eq",
            args: [
              ExpressionFactory.function_arg("arg1", ExpressionFactory.param(0)),
              ExpressionFactory.function_arg("arg2", ExpressionFactory.constant("string", "foo"))
            ]
          )
      )

      expression =
        ExpressionFactory.function(
          type: "boolean",
          name: "eq_to_foo",
          args: [
            ExpressionFactory.function_arg("value", ExpressionFactory.constant("string", "bar"))
          ]
        )

      assert Expression.unfold(expression) == %{
               __type__: "function",
               type: "boolean",
               name: "eq",
               args: [
                 %{
                   __type__: "function_arg",
                   name: "arg1",
                   expression: %{__type__: "constant", type: "string", value: "bar"}
                 },
                 %{
                   __type__: "function_arg",
                   name: "arg2",
                   expression: %{__type__: "constant", type: "string", value: "foo"}
                 }
               ]
             }
    end
  end
end
