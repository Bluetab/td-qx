defmodule TdQx.DataViews.QueryableTest do
  use TdQx.DataCase

  import QueryableHelpers

  alias TdQx.DataViews.Queryable
  alias TdQx.ExpressionFactory
  alias TdQx.QueryableFactory

  describe "Queryable changeset" do
    for type <- ~w|from join select where group_by| do
      @tag type: type
      test "test valid changeset for type #{type}", %{type: type} do
        params = %{
          id: 1,
          type: type,
          alias: "alias",
          properties: valid_properties_for(type)
        }

        assert %{valid?: true} = Queryable.changeset(%Queryable{}, params)
      end
    end

    test "test invalid type" do
      params = %{
        id: 1,
        type: "invalid",
        properties: %{}
      }

      assert %{valid?: false, errors: errors} = Queryable.changeset(%Queryable{}, params)

      assert [
               type: {"is invalid", [{:validation, :inclusion}, _]}
             ] = errors
    end

    test "test required fields" do
      params = %{}
      assert %{valid?: false, errors: errors} = Queryable.changeset(%Queryable{}, params)

      assert [
               {:id, {"can't be blank", [validation: :required]}},
               {:type, {"can't be blank", [validation: :required]}},
               {:properties, {"can't be blank", [validation: :required]}}
             ] = errors
    end
  end

  describe "Queryable.unfold/2 of type `join`" do
    test "constant join expression" do
      join_type = "inner"
      resource = build(:resource, type: "data_structure", id: 888)
      expression = ExpressionFactory.constant("boolean", "true")
      clause = build(:clause, expressions: [expression])

      queryable_id = 0
      queryable_alias = "JOIN1"

      join =
        QueryableFactory.join(join_type, resource, [clause],
          id: queryable_id,
          alias: queryable_alias
        )

      assert {result_resource_refs,
              [
                %{
                  __type__: "join",
                  type: ^join_type,
                  resource_ref: ^queryable_id,
                  resource: nil,
                  clauses: result_clauses
                }
              ]} = Queryable.unfold(join)

      assert Map.get(result_resource_refs, queryable_id) ==
               %{
                 type: "data_structure",
                 id: resource.id,
                 alias: queryable_alias
               }

      assert result_clauses == [[%{__type__: "constant", type: "boolean", value: "true"}]]
    end
  end

  describe "Queryable.unfold/2 of type `from`" do
    test "unfolds data_structure resource" do
      resource = build(:resource, type: "data_structure")

      from =
        QueryableFactory.from(resource,
          id: 0,
          alias: "alias"
        )

      assert {updated_resource_refs, [from]} = Queryable.unfold(from)

      assert Map.get(updated_resource_refs, 0) == %{
               type: "data_structure",
               id: resource.id,
               alias: "alias"
             }

      assert from == %{__type__: "from", resource_ref: 0, resource: nil}
    end

    test "unfolds reference_dataset resource" do
      resource = build(:resource, type: "reference_dataset")

      from =
        QueryableFactory.from(resource,
          id: 0,
          alias: "alias"
        )

      assert {updated_resource_refs, [from]} = Queryable.unfold(from)

      assert Map.get(updated_resource_refs, 0) == %{
               type: "reference_dataset",
               id: resource.id,
               alias: "alias"
             }

      assert from == %{__type__: "from", resource_ref: 0, resource: nil}
    end

    test "unfolds a nested data view" do
      resource = build(:resource, type: "data_structure", id: 888)

      from =
        QueryableFactory.from(resource,
          id: 11,
          alias: "nested_alias"
        )

      field_alias = "column1"
      field_value = "foo"

      %{id: select_queryable_id} =
        select =
        QueryableFactory.select([
          [alias: field_alias, expression: ExpressionFactory.constant("string", field_value)]
        ])

      nested_data_view = insert(:data_view, queryables: [from], select: select)

      resource = build(:resource, type: "data_view", id: nested_data_view.id)

      from_resource_ref = 22
      from = QueryableFactory.from(resource, id: from_resource_ref, alias: "parent_alias")

      assert {updated_resource_refs, [from]} = Queryable.unfold(from)

      assert updated_resource_refs == %{
               from_resource_ref => %{
                 alias: "parent_alias",
                 id: nested_data_view.id,
                 type: "data_view"
               }
             }

      assert from == %{
               __type__: "from",
               resource_ref: from_resource_ref,
               resource: %{
                 __type__: "data_view",
                 queryables: [
                   %{__type__: "from", resource_ref: 11, resource: nil}
                 ],
                 select: %{
                   __type__: "select",
                   fields: [
                     %{
                       __type__: "select_field",
                       alias: field_alias,
                       expression: %{
                         __type__: "constant",
                         type: "string",
                         value: field_value
                       }
                     }
                   ],
                   resource_ref: select_queryable_id
                 },
                 resource_refs: %{
                   11 => %{
                     type: "data_structure",
                     id: 888,
                     alias: "nested_alias"
                   }
                 }
               }
             }
    end
  end

  describe "Queryable.unfold/2 of type `where`" do
    test "clause with a constant expression" do
      expression = ExpressionFactory.constant("boolean", "true")

      clause = build(:clause, expressions: [expression])

      where = QueryableFactory.where([clause], alias: "alias")

      assert {%{}, [%{__type__: "where", clauses: [[constant_expression]]}]} =
               Queryable.unfold(where)

      assert constant_expression == %{__type__: "constant", type: "boolean", value: "true"}
    end
  end

  describe "Queryable.unfold/2 of type `select`" do
    test "select_field with a constant expression" do
      expression = ExpressionFactory.constant("string", "foo")

      queryable_id = 8
      queryable_alias = "select_alias"

      select =
        QueryableFactory.select(
          [
            [alias: "COL1", expression: expression]
          ],
          id: queryable_id,
          alias: queryable_alias
        )

      assert {resource_refs, [%{__type__: "select", fields: fields, resource_ref: ^queryable_id}]} =
               Queryable.unfold(select)

      assert resource_refs == %{
               queryable_id => %{
                 type: "select",
                 id: nil,
                 alias: queryable_alias
               }
             }

      assert fields == [
               %{
                 __type__: "select_field",
                 alias: "COL1",
                 expression: %{
                   __type__: "constant",
                   type: "string",
                   value: "foo"
                 }
               }
             ]
    end
  end

  describe "Queryable.unfold/2 of type `group_by`" do
    test "with a constant expressions" do
      group_fields = [
        [alias: "COL1", expression: ExpressionFactory.constant("string", "foo")]
      ]

      agg_fields = [
        [alias: "sum", expression: ExpressionFactory.constant("string", "bar")]
      ]

      queryable_id = 9
      queryable_alias = "group_by_alias"

      group_by =
        QueryableFactory.group_by(group_fields, agg_fields,
          id: queryable_id,
          alias: queryable_alias
        )

      assert {resource_refs,
              [
                %{
                  __type__: "group_by",
                  group_fields: group_fields,
                  aggregate_fields: agg_fields,
                  resource_ref: ^queryable_id
                }
              ]} = Queryable.unfold(group_by)

      assert resource_refs == %{
               queryable_id => %{
                 type: "group_by",
                 id: nil,
                 alias: queryable_alias
               }
             }

      assert group_fields == [
               %{
                 __type__: "select_field",
                 alias: "COL1",
                 expression: %{__type__: "constant", type: "string", value: "foo"}
               }
             ]

      assert agg_fields == [
               %{
                 __type__: "select_field",
                 alias: "sum",
                 expression: %{__type__: "constant", type: "string", value: "bar"}
               }
             ]
    end
  end
end
