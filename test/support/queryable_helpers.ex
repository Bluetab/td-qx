defmodule QueryableHelpers do
  @moduledoc """
  Helper functions for Queryable tests
  """

  import TdQx.Factory

  def valid_properties_for(type, attrs \\ [])

  def valid_properties_for("join", attrs), do: string_params_for(:qp_join_params_for, attrs)
  def valid_properties_for("from", attrs), do: string_params_for(:qp_from, attrs)

  def valid_properties_for("where", attrs),
    do: string_params_for(:qp_where_params_for, attrs)

  def valid_properties_for("select", attrs),
    do: string_params_for(:qp_select_params_for, attrs)

  def valid_properties_for("group_by", attrs) do
    params = string_params_for(:qp_group_by_params_for, attrs)

    %{
      "aggregate_fields" => [
        %{
          "expression" => %{
            "value" => %{
              "name" => function_name,
              "type" => function_type
            }
          }
        }
      ]
    } = params

    insert(:function, name: function_name, type: function_type, class: "aggregator")
    params
  end

  def valid_properties_for(_, _), do: %{}

  def valid_queryable_params_for(type, attrs \\ [], properties_attrs \\ [])

  def valid_queryable_params_for("join", attrs, properties_attrs),
    do:
      params_for(
        :data_view_queryable,
        [type: "join", properties: build(:qp_join_params_for, properties_attrs)] ++ attrs
      )

  def valid_queryable_params_for("from", attrs, properties_attrs),
    do:
      params_for(
        :data_view_queryable,
        [type: "from", properties: build(:qp_from, properties_attrs)] ++ attrs
      )

  def valid_queryable_params_for("select", attrs, properties_attrs),
    do:
      params_for(
        :data_view_queryable,
        [type: "select", properties: build(:qp_select_params_for, properties_attrs)] ++ attrs
      )

  def valid_queryable_params_for("where", attrs, properties_attrs),
    do:
      params_for(
        :data_view_queryable,
        [type: "where", properties: build(:qp_where_params_for, properties_attrs)] ++ attrs
      )

  def valid_queryable_params_for("group_by", attrs, properties_attrs),
    do:
      params_for(
        :data_view_queryable,
        [type: "group_by", properties: build(:qp_group_by_params_for, properties_attrs)] ++ attrs
      )

  def insert_data_view_with_from_resource(resource),
    do:
      insert(:data_view,
        queryables: [
          build(:data_view_queryable,
            type: "from",
            properties: %{from: build(:qp_from, resource: resource)}
          )
        ]
      )

  def drop_properties_embedded(%{"resource" => resource} = prop),
    do: Map.put(prop, "resource", Map.delete(resource, "embedded"))

  def drop_properties_embedded(prop), do: prop
end
