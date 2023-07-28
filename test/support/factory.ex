defmodule TdQx.Factory do
  @moduledoc """
  An `ExMachina` factory for data quality tests.
  """

  use ExMachina.Ecto, repo: TdQx.Repo

  alias TdQx.DataSets.DataSet
  alias TdQx.Functions.Expression
  alias TdQx.Functions.Function
  alias TdQx.Functions.Param

  def user_factory do
    %{
      id: System.unique_integer([:positive]),
      role: "user",
      user_name: sequence("user_name"),
      full_name: sequence("full_name"),
      external_id: sequence("user_external_id"),
      email: sequence("email") <> "@example.com"
    }
  end

  def data_set_factory(attrs) do
    data_structure_id = sequence(:data_structure_id, & &1)

    %DataSet{
      name: sequence(:dataset_name, &"DataSet #{&1})"),
      data_structure_id: data_structure_id,
      data_structure: build(:data_structure, data_structure_id: data_structure_id)
    }
    |> merge_attributes(attrs)
  end

  def data_structure_factory(attrs) do
    %{
      id: sequence(:id, & &1),
      system_id: sequence(:system_id, & &1),
      external_id: sequence(:data_structure_external_id, &"external_id_#{&1})")
    }
    |> merge_attributes(attrs)
  end

  def function_factory(attrs) do
    %Function{
      name: "some name",
      type: "boolean",
      description: "some description",
      params: [
        build(:function_param)
      ],
      expression: build(:function_expression)
    }
    |> merge_attributes(attrs)
  end

  def function_param_factory(attrs) do
    %Param{
      name: "some name",
      type: "boolean",
      description: "some description"
    }
    |> merge_attributes(attrs)
  end

  def function_expression_factory(attrs) do
    %Expression{
      shape: "constant",
      value: %{
        type: "string",
        value: "some value"
      }
    }
    |> merge_attributes(attrs)
  end
end
