defmodule TdQx.FunctionsTest do
  use TdQx.DataCase

  alias TdQx.Expressions.Expression
  alias TdQx.Functions
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

      assert %Expression{
               shape: "constant",
               value: %{
                 constant: %{
                   type: "string",
                   value: "some expression"
                 }
               }
             } = function.expression

      assert function.name == "some name"

      assert [
               %Param{name: "param1", type: "string", description: nil}
             ] = function.params

      assert function.type == "boolean"
    end

    test "create_function/1 with valid function shape expression returns correct args format" do
      insert(:function,
        name: "func1",
        type: "boolean",
        params: [
          build(:function_param, name: "param1", type: "boolean")
        ]
      )

      valid_attrs = %{
        description: "some description",
        expression: %{
          shape: "function",
          value: %{
            name: "func1",
            type: "boolean",
            args: %{
              param1: %{
                shape: "constant",
                value: %{
                  type: "boolean",
                  value: "true"
                }
              }
            }
          }
        },
        name: "some name",
        params: [%{id: 1, name: "param1", type: "string"}],
        type: "boolean"
      }

      assert {:ok, %Function{} = function} = Functions.create_function(valid_attrs)

      assert function.description == "some description"

      assert %Expression{
               shape: "function",
               value: %{
                 function: %{
                   name: "func1",
                   type: "boolean",
                   args: [
                     %{
                       name: "param1",
                       expression: %{
                         shape: "constant",
                         value: %{
                           constant: %{type: "boolean", value: "true"}
                         }
                       }
                     }
                   ]
                 }
               }
             } = function.expression

      assert function.name == "some name"

      assert [
               %Param{name: "param1", type: "string", description: nil}
             ] = function.params

      assert function.type == "boolean"
    end

    test "create_function/1 will not allow to create a function with duplicated name and type" do
      valid_attrs = %{
        name: "some name",
        type: "boolean"
      }

      assert {:ok, %Function{}} = Functions.create_function(valid_attrs)

      assert {:error,
              %{
                errors: [
                  name:
                    {"has already been taken",
                     [constraint: :unique, constraint_name: "functions_name_type_index"]}
                ]
              }} = Functions.create_function(valid_attrs)
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
                       enum: ["boolean", "string", "number", "date", "timestamp", "any"]
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

      assert %Expression{
               shape: "constant",
               value: %{
                 constant: %{
                   type: "string",
                   value: "some expression"
                 }
               }
             } = function.expression

      assert function.name == "some updated name"

      assert [
               %Param{name: "param1", type: "string", description: nil}
             ] = function.params

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
end
