defmodule TdQx.QueryableFactory do
  @moduledoc """
  Factory for queryable resources.
  """
  import TdQx.Factory

  def from(resource, attrs \\ []) do
    build(
      :data_view_queryable,
      [
        type: "from",
        properties:
          build(:queryable_properties,
            from: build(:qp_from, resource: resource)
          )
      ] ++ attrs
    )
  end

  def where(clauses, attrs \\ []) do
    build(
      :data_view_queryable,
      [
        type: "where",
        properties:
          build(:queryable_properties,
            where: build(:qp_where, clauses: clauses)
          )
      ] ++ attrs
    )
  end

  def select(field_attrs, attrs \\ []) do
    build(
      :data_view_queryable,
      [
        type: "select",
        properties:
          build(:queryable_properties,
            select: build(:qp_select, fields: Enum.map(field_attrs, &build(:qp_select_field, &1)))
          )
      ] ++ attrs
    )
  end

  def join(type, resource, clauses, attrs \\ []) do
    build(
      :data_view_queryable,
      [
        type: "join",
        properties:
          build(:queryable_properties,
            join:
              build(:qp_join,
                resource: resource,
                type: type,
                clauses: clauses
              )
          )
      ] ++ attrs
    )
  end

  def group_by(group_field_attrs, agg_field_attrs, attrs \\ []) do
    build(
      :data_view_queryable,
      [
        type: "group_by",
        properties:
          build(:queryable_properties,
            group_by:
              build(:qp_group_by,
                group_fields: Enum.map(group_field_attrs, &build(:qp_select_field, &1)),
                aggregate_fields: Enum.map(agg_field_attrs, &build(:qp_select_field, &1))
              )
          )
      ] ++ attrs
    )
  end
end
