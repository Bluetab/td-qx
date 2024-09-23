defmodule TdQx.Factory do
  @moduledoc """
  An `ExMachina` factory for data quality tests.
  """

  use ExMachina.Ecto, repo: TdQx.Repo

  alias TdQx.DataViews.DataView
  alias TdQx.DataViews.Queryable
  alias TdQx.DataViews.QueryableProperties
  alias TdQx.DataViews.Resource

  alias TdQx.Executions.Execution
  alias TdQx.Executions.ExecutionGroup

  alias TdQx.Expressions.Expression
  alias TdQx.Expressions.ExpressionValue
  alias TdQx.Expressions.ExpressionValues

  alias TdQx.Functions.Function
  alias TdQx.Functions.Param

  alias TdQx.QualityControls.QualityControl
  alias TdQx.QualityControls.QualityControlVersion
  alias TdQx.QualityControls.ResultCriteria
  alias TdQx.QualityControls.ResultCriterias

  def domain_factory do
    %{
      name: sequence("domain_name"),
      id: System.unique_integer([:positive]),
      external_id: sequence("domain_external_id"),
      updated_at: DateTime.utc_now(),
      parent_id: nil
    }
  end

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

  def data_view_factory(attrs) do
    %DataView{
      name: sequence(:data_view_name, &"DataView #{&1}"),
      description: sequence(:dataset_description, &"dataset description #{&1}"),
      created_by_id: sequence(:created_by_id, & &1),
      source_id: 10,
      queryables: [
        build(:data_view_queryable)
      ],
      select:
        build(:data_view_queryable,
          type: "select",
          properties: build(:queryable_properties, select: build(:qp_select))
        )
    }
    |> merge_attributes(attrs)
  end

  def data_view_params_for_factory(attrs) do
    %DataView{
      name: sequence(:data_view_name, &"DataView #{&1}"),
      description: sequence(:dataset_description, &"dataset description #{&1}"),
      created_by_id: sequence(:created_by_id, & &1),
      source_id: sequence(:source_id, & &1),
      queryables: [
        build(:data_view_queryable_params_for)
      ],
      select:
        build(:data_view_queryable,
          type: "select",
          properties: build(:qp_select_params_for)
        )
    }
    |> merge_attributes(attrs)
  end

  def data_view_queryable_factory(attrs) do
    %Queryable{
      id: sequence(:queryable_id, & &1),
      type: "from",
      alias: sequence(:data_view_alias, &"alias_#{&1}"),
      properties: build(:queryable_properties, from: build(:qp_from))
    }
    |> merge_attributes(attrs)
  end

  def data_view_queryable_params_for_factory(attrs) do
    %Queryable{
      id: sequence(:queryable_id, & &1),
      type: "from",
      alias: sequence(:data_view_alias, &"alias_#{&1}"),
      properties: build(:qp_from)
    }
    |> merge_attributes(attrs)
  end

  def queryable_properties_factory(%{from: %{} = from}), do: %QueryableProperties{from: from}
  def queryable_properties_factory(%{join: %{} = join}), do: %QueryableProperties{join: join}

  def queryable_properties_factory(%{select: %{} = select}),
    do: %QueryableProperties{select: select}

  def queryable_properties_factory(%{where: %{} = where}), do: %QueryableProperties{where: where}

  def queryable_properties_factory(%{group_by: %{} = group_by}),
    do: %QueryableProperties{group_by: group_by}

  def queryable_properties_factory(_), do: %QueryableProperties{join: build(:qp_join)}

  def qp_join_factory(attrs) do
    %QueryableProperties.Join{
      resource: build(:resource),
      clauses: [build(:clause)],
      type: "left"
    }
    |> merge_attributes(attrs)
  end

  def qp_join_params_for_factory(attrs) do
    %QueryableProperties.Join{
      resource: build(:resource),
      clauses: [build(:clause_params_for)],
      type: "left"
    }
    |> merge_attributes(attrs)
  end

  def qp_from_factory(attrs) do
    %QueryableProperties.From{
      resource: build(:resource)
    }
    |> merge_attributes(attrs)
  end

  def qp_select_field_factory(attrs) do
    %QueryableProperties.SelectField{
      id: sequence(:qp_select_field_id, & &1),
      expression: build(:expression),
      alias: sequence(:qp_select_field_alias, &"alias_#{&1}")
    }
    |> merge_attributes(attrs)
  end

  def qp_select_factory(attrs) do
    %QueryableProperties.Select{
      fields: [
        build(:qp_select_field)
      ]
    }
    |> merge_attributes(attrs)
  end

  def qp_group_by_factory(attrs) do
    %{name: name, type: type} = insert(:function, class: "aggregator")

    %QueryableProperties.GroupBy{
      group_fields: [
        build(:qp_select_field)
      ],
      aggregate_fields: [
        build(:qp_select_field,
          expression:
            build(:expression,
              shape: "function",
              value:
                build(:expression_value, %{
                  function:
                    build(
                      :ev_function,
                      name: name,
                      type: type
                    )
                })
            )
        )
      ]
    }
    |> merge_attributes(attrs)
  end

  def qp_select_field_params_for_factory(attrs) do
    %QueryableProperties.SelectField{
      id: sequence(:qp_select_field_id, & &1),
      expression: build(:expression_params_for),
      alias: sequence(:qp_select_field_alias, &"alias_#{&1}")
    }
    |> merge_attributes(attrs)
  end

  def qp_select_params_for_factory(attrs) do
    %QueryableProperties.Select{
      fields: [
        build(:qp_select_field_params_for)
      ]
    }
    |> merge_attributes(attrs)
  end

  def qp_group_by_params_for_factory(attrs) do
    %QueryableProperties.GroupBy{
      group_fields: [
        build(:qp_select_field_params_for)
      ],
      aggregate_fields: [
        build(:qp_select_field_params_for,
          expression:
            build(:expression_params_for,
              shape: "function",
              value: build(:ev_function)
            )
        )
      ]
    }
    |> merge_attributes(attrs)
  end

  def qp_where_factory(attrs) do
    %QueryableProperties.Where{
      clauses: [build(:clause)]
    }
    |> merge_attributes(attrs)
  end

  def qp_where_params_for_factory(attrs) do
    %QueryableProperties.Where{
      clauses: [build(:clause_params_for)]
    }
    |> merge_attributes(attrs)
  end

  def resource_factory(attrs) do
    %Resource{
      id: sequence(:resource_id, & &1),
      type: "data_view"
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
      expression: build(:expression)
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

  def expression_params_for_factory(attrs) do
    %Expression{
      shape: "constant",
      value: build(:ev_constant)
    }
    |> merge_attributes(attrs)
  end

  def expression_factory(attrs) do
    %Expression{
      shape: "constant",
      value: build(:expression_value, constant: build(:ev_constant))
    }
    |> merge_attributes(attrs)
  end

  def expression_value_factory(%{constant: %{} = constant}),
    do: %ExpressionValue{constant: constant}

  def expression_value_factory(%{field: %{} = field}), do: %ExpressionValue{field: field}

  def expression_value_factory(%{function: %{} = function}),
    do: %ExpressionValue{function: function}

  def expression_value_factory(%{param: %{} = param}), do: %ExpressionValue{param: param}

  def expression_value_factory(_), do: %ExpressionValue{constant: build(:ev_constant)}

  def ev_constant_factory(attrs) do
    %ExpressionValues.Constant{
      type: "string",
      value: sequence(:ev_constant_value, &"value #{&1}")
    }
    |> merge_attributes(attrs)
  end

  def ev_field_factory(attrs) do
    %ExpressionValues.Field{
      id: sequence(:ev_field_id, & &1),
      type: "string",
      name: sequence(:ev_field_name, &"name #{&1}"),
      parent_id: 0
    }
    |> merge_attributes(attrs)
  end

  def ev_function_factory(attrs) do
    %ExpressionValues.Function{
      type: "boolean",
      name: sequence(:ev_function_name, &"name #{&1}"),
      args: nil
    }
    |> merge_attributes(attrs)
  end

  def ev_function_arg_factory(attrs) do
    %ExpressionValues.FunctionArg{
      name: "some name",
      expression: build(:expression)
    }
    |> merge_attributes(attrs)
  end

  def ev_param_factory(attrs) do
    %ExpressionValues.Param{
      id: sequence(:ev_param_id, & &1)
    }
    |> merge_attributes(attrs)
  end

  def clause_factory(attrs) do
    %TdQx.Expressions.Clause{
      expressions: [
        build(:expression)
      ]
    }
    |> merge_attributes(attrs)
  end

  def clause_params_for_factory(attrs) do
    %TdQx.Expressions.Clause{
      expressions: [
        build(:expression_params_for)
      ]
    }
    |> merge_attributes(attrs)
  end

  def reference_dataset_factory(attrs) do
    %{
      id: sequence(:reference_dataset_id, & &1),
      name: sequence(:reference_dataset_name, &"name #{&1}"),
      headers: ["header1", "header2"]
    }
    |> merge_attributes(attrs)
  end

  def quality_control_factory(attrs) do
    %QualityControl{
      domain_ids: [1, 2],
      source_id: 10
    }
    |> merge_attributes(attrs)
  end

  def execution_groups_factory(attrs) do
    %ExecutionGroup{
      df_content: %{},
      executions: for(_id <- [1, 2, 3], do: execution_factory(%{}))
    }
    |> merge_attributes(attrs)
  end

  def execution_factory(attrs) do
    %Execution{
      status: "pending"
    }
    |> merge_attributes(attrs)
  end

  def quality_control_version_factory(attrs) do
    %QualityControlVersion{
      name: sequence(:quality_control_name, &"name #{&1}"),
      version: 1,
      status: "draft",
      df_content: %{},
      df_type: "some df_type",
      result_criteria: build(:result_criteria),
      result_type: "percentage",
      resource: build(:resource),
      validation: [build(:clause)]
    }
    |> merge_attributes(attrs)
  end

  def quality_control_params_factory(attrs) do
    %{
      domain_ids: [1, 2],
      name: sequence(:quality_control_name, &"name #{&1}"),
      source_id: 10,
      version: 1,
      status: "draft",
      df_content: %{},
      df_type: "some df_type",
      result_criteria: build(:rc_percentage),
      result_type: "percentage",
      resource: build(:resource),
      validation: [build(:clause_params_for)]
    }
    |> merge_attributes(attrs)
  end

  def quality_control_version_params_for_factory(attrs) do
    %QualityControlVersion{
      quality_control: build(:quality_control),
      name: sequence(:quality_control_name, &"name #{&1}"),
      version: 1,
      status: "draft",
      df_content: %{},
      df_type: "some df_type",
      result_criteria: build(:rc_percentage),
      result_type: "percentage",
      resource: build(:resource),
      validation: [build(:clause_params_for)]
    }
    |> merge_attributes(attrs)
  end

  def result_criteria_factory(%{deviation: %{} = deviation}),
    do: %ResultCriteria{deviation: deviation}

  def result_criteria_factory(%{errors_number: %{} = errors_number}),
    do: %ResultCriteria{errors_number: errors_number}

  def result_criteria_factory(%{percentage: %{} = percentage}),
    do: %ResultCriteria{percentage: percentage}

  def result_criteria_factory(_), do: %ResultCriteria{percentage: build(:rc_percentage)}

  def rc_deviation_factory(attrs) do
    %ResultCriterias.Deviation{
      goal: 5.0,
      maximum: 15.0
    }
    |> merge_attributes(attrs)
  end

  def rc_errors_number_factory(attrs) do
    %ResultCriterias.ErrorsNumber{
      goal: 10,
      maximum: 100
    }
    |> merge_attributes(attrs)
  end

  def rc_percentage_factory(attrs) do
    %ResultCriterias.Percentage{
      goal: 90.0,
      minimum: 75.0
    }
    |> merge_attributes(attrs)
  end
end
