defmodule TdQx.Expressions.ExpressionTest do
  use TdQx.DataCase

  alias Ecto.Changeset
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
end
