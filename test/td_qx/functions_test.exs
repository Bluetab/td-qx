defmodule TdQx.FunctionsTest do
  use TdQx.DataCase

  alias TdQx.Functions
  alias TdQx.Functions.Expression
  alias TdQx.Functions.Function
  alias TdQx.Functions.Param

  describe "functions" do
    test "list_functions/0 returns all functions" do
      function = insert(:function)
      assert Functions.list_functions() == [function]
    end

    test "get_function!/1 returns the function with given id" do
      function = insert(:function)
      assert Functions.get_function!(function.id) == function
    end

    test "create_function/1 with valid data creates a function" do
      valid_attrs = %{
        description: "some description",
        expression: %{
          shape: "constant",
          value: %{
            type: "string",
            value: "some expression"
          }
        },
        name: "some name",
        params: [%{id: 1, name: "param1", type: "string"}],
        type: "boolean"
      }

      assert {:ok, %Function{} = function} = Functions.create_function(valid_attrs)
      assert function.description == "some description"

      assert function.expression == %Expression{
               shape: "constant",
               value: %{
                 type: "string",
                 value: "some expression"
               }
             }

      assert function.name == "some name"

      assert function.params == [
               %Param{name: "param1", type: "string", description: nil}
             ]

      assert function.type == "boolean"
    end

    test "create_function/1 with invalid data returns error changeset" do
      invalid_attrs = %{
        description: nil,
        expression: nil,
        name: nil,
        params: nil,
        type: nil
      }

      assert {:error, %Ecto.Changeset{}} = Functions.create_function(invalid_attrs)
    end

    test "create_function/1 with invalid type returns error changeset" do
      valid_attrs = %{
        description: "some description",
        name: "some name",
        type: "invalid_type"
      }

      assert {:error,
              %Ecto.Changeset{
                errors: [
                  type:
                    {"is invalid",
                     [
                       validation: :inclusion,
                       enum: ["boolean", "string", "numeric", "date", "timestamp", "any"]
                     ]}
                ]
              }} = Functions.create_function(valid_attrs)
    end

    test "update_function/2 with valid data updates the function" do
      function = insert(:function)

      update_attrs = %{
        description: "some updated description",
        expression: %{
          shape: "constant",
          value: %{
            type: "string",
            value: "some expression"
          }
        },
        name: "some updated name",
        params: [%{id: 1, name: "param1", type: "string"}],
        type: "string"
      }

      assert {:ok, %Function{} = function} = Functions.update_function(function, update_attrs)
      assert function.description == "some updated description"

      assert function.expression == %Expression{
               shape: "constant",
               value: %{
                 type: "string",
                 value: "some expression"
               }
             }

      assert function.name == "some updated name"

      assert function.params == [
               %Param{name: "param1", type: "string", description: nil}
             ]

      assert function.type == "string"
    end

    test "update_function/2 with invalid data returns error changeset" do
      invalid_attrs = %{
        description: nil,
        expression: nil,
        name: nil,
        params: nil,
        type: nil
      }

      function = insert(:function)
      assert {:error, %Ecto.Changeset{}} = Functions.update_function(function, invalid_attrs)
      assert function == Functions.get_function!(function.id)
    end

    test "delete_function/1 deletes the function" do
      function = insert(:function)
      assert {:ok, %Function{}} = Functions.delete_function(function)
      assert_raise Ecto.NoResultsError, fn -> Functions.get_function!(function.id) end
    end

    test "change_function/1 returns a function changeset" do
      function = insert(:function)
      assert %Ecto.Changeset{} = Functions.change_function(function)
    end
  end

  describe "functions expression" do
    test "create_function/1 validates expression shape" do
      valid_attrs = %{
        expression: %{
          shape: "invalid_shape",
          value: %{}
        },
        name: "name",
        type: "boolean"
      }

      assert {:error, _} = Functions.create_function(valid_attrs)
    end

    test "create_function/1 validates constant shape value" do
      valid_attrs = %{
        expression: %{
          shape: "constant",
          value: %{
            type: "invalid_type"
          }
        },
        name: "name",
        type: "boolean"
      }

      assert {:error, _} = Functions.create_function(valid_attrs)
    end

    test "create_function/1 creates valid shape constant" do
      valid_attrs = %{
        expression: %{
          shape: "constant",
          value: %{
            type: "boolean",
            value: "true"
          }
        },
        name: "name",
        type: "boolean"
      }

      assert {:ok, %Function{expression: expression}} = Functions.create_function(valid_attrs)

      assert %Expression{
               shape: "constant",
               value: %{
                 type: "boolean",
                 value: "true"
               }
             } = expression
    end

    test "create_function/1 validates field shape value" do
      valid_attrs = %{
        expression: %{
          shape: "field",
          value: %{
            type: "invalid_type"
          }
        },
        name: "name",
        type: "boolean"
      }

      assert {:error, _} = Functions.create_function(valid_attrs)
    end

    test "create_function/1 creates valid shape field" do
      valid_attrs = %{
        expression: %{
          shape: "field",
          value: %{
            type: "boolean",
            name: "field1",
            dataset: %{}
          }
        },
        name: "name",
        type: "boolean"
      }

      assert {:ok, %Function{expression: expression}} = Functions.create_function(valid_attrs)

      assert %Expression{
               shape: "field",
               value: %{
                 type: "boolean",
                 name: "field1",
                 dataset: %{}
               }
             } = expression
    end

    test "create_function/1 validates function shape value" do
      valid_attrs = %{
        expression: %{
          shape: "function",
          value: %{
            type: "invalid_type"
          }
        },
        name: "name",
        type: "boolean"
      }

      assert {:error, _} = Functions.create_function(valid_attrs)
    end

    test "create_function/1 creates valid shape function" do
      valid_attrs = %{
        expression: %{
          shape: "function",
          value: %{
            type: "boolean",
            name: "func1",
            args: %{}
          }
        },
        name: "name",
        type: "boolean"
      }

      assert {:ok, %Function{expression: expression}} = Functions.create_function(valid_attrs)

      assert %Expression{
               shape: "function",
               value: %{
                 type: "boolean",
                 name: "func1",
                 args: %{}
               }
             } = expression
    end

    test "create_function/1 validates param shape value" do
      valid_attrs = %{
        expression: %{
          shape: "param",
          value: %{
            id: nil
          }
        },
        name: "name",
        type: "boolean"
      }

      assert {:error, _} = Functions.create_function(valid_attrs)
    end

    test "create_function/1 creates valid shape param" do
      valid_attrs = %{
        expression: %{
          shape: "param",
          value: %{
            id: 1
          }
        },
        name: "name",
        type: "boolean"
      }

      assert {:ok, %Function{expression: expression}} = Functions.create_function(valid_attrs)

      assert %Expression{
               shape: "param",
               value: %{
                 id: 1
               }
             } = expression
    end
  end
end
