defmodule TdQx.DataViews.DataViewTest do
  use TdQx.DataCase

  alias TdQx.DataViews.DataView
  alias TdQx.ExpressionFactory
  alias TdQx.QueryableFactory

  describe "DataView.unfold/1" do
    test "unfolds a `where` clause referencing a field in a parent data structure" do
      parent_id = 1
      resource_id = 888
      field_id = 2
      field_name = "field2"

      resource = build(:resource, type: "data_structure", id: resource_id)
      from = QueryableFactory.from(resource, id: parent_id, alias: "alias")

      expression = ExpressionFactory.field(parent_id: parent_id, id: field_id, name: field_name)
      clause = build(:clause, expressions: [expression])
      where = QueryableFactory.where([clause])

      field_alias = "column1"
      field_value = "foo"

      %{id: select_queryable_id} =
        select =
        QueryableFactory.select([
          [alias: field_alias, expression: ExpressionFactory.constant("string", field_value)]
        ])

      data_view = insert(:data_view, queryables: [from, where], select: select)

      assert %{
               __type__: "data_view",
               queryables: data_view_queryables,
               select: select,
               resource_refs: resource_refs
             } = DataView.unfold(data_view)

      assert select == %{
               __type__: "select",
               fields: [
                 %{
                   __type__: "select_field",
                   alias: field_alias,
                   expression: %{__type__: "constant", type: "string", value: field_value}
                 }
               ],
               resource_ref: select_queryable_id
             }

      assert data_view_queryables == [
               %{__type__: "from", resource_ref: parent_id, resource: nil},
               %{
                 __type__: "where",
                 clauses: [
                   [%{__type__: "field", id: field_id, name: field_name, parent_id: parent_id}]
                 ]
               }
             ]

      assert resource_refs == %{
               parent_id => %{
                 type: "data_structure",
                 id: resource_id,
                 alias: "alias"
               }
             }
    end

    test "unfolds a dataview with a nested dataview" do
      insert(:function,
        type: "boolean",
        name: "eq",
        params: [
          build(:function_param, name: "arg1", type: "any"),
          build(:function_param, name: "arg2", type: "any")
        ],
        expression: nil
      )

      insert(:function,
        type: "boolean",
        name: "and",
        params: [
          build(:function_param, name: "arg1", type: "boolean"),
          build(:function_param, name: "arg2", type: "boolean")
        ],
        expression: nil
      )

      nested_from_resource_id = 888
      nested_from_qid = 0
      resource = build(:resource, type: "data_structure", id: nested_from_resource_id)
      from = QueryableFactory.from(resource, id: nested_from_qid, alias: "nested_from_alias")

      %{id: nested_select_id} =
        nested_select =
        QueryableFactory.select([
          [
            alias: "nested_select_field",
            expression: ExpressionFactory.constant("string", "nested_foo")
          ]
        ])

      nested_data_view = insert(:data_view, queryables: [from], select: nested_select)

      from_resource_id = 11
      from_qid = 1
      resource = build(:resource, type: "data_structure", id: from_resource_id)
      from = QueryableFactory.from(resource, id: from_qid, alias: "from_alias")

      join_qid = 5

      field_id1 = 6
      field_id2 = 7

      expression =
        ExpressionFactory.function(
          type: "boolean",
          name: "eq",
          args: [
            ExpressionFactory.function_arg(
              "arg1",
              ExpressionFactory.field(
                parent_id: from_qid,
                id: field_id1,
                name: "field_#{field_id1}"
              )
            ),
            ExpressionFactory.function_arg(
              "arg2",
              ExpressionFactory.field(
                parent_id: join_qid,
                id: field_id2,
                name: "field_#{field_id2}"
              )
            )
          ]
        )

      clause = build(:clause, expressions: [expression])
      resource = build(:resource, type: "data_view", id: nested_data_view.id)

      join =
        QueryableFactory.join("inner", resource, [clause],
          id: join_qid,
          alias: "join_alias"
        )

      expression =
        ExpressionFactory.function(
          type: "boolean",
          name: "and",
          args: [
            ExpressionFactory.function_arg("arg1", ExpressionFactory.constant("boolean", "true")),
            ExpressionFactory.function_arg("arg2", ExpressionFactory.constant("boolean", "false"))
          ]
        )

      clause = build(:clause, expressions: [expression])
      where = QueryableFactory.where([clause], alias: "where_alias")

      %{id: select_queryable_id} =
        select =
        QueryableFactory.select([
          [alias: "select_field", expression: ExpressionFactory.constant("string", "foo")]
        ])

      data_view = insert(:data_view, queryables: [from, join, where], select: select)

      assert %{
               __type__: "data_view",
               queryables: queryables,
               select: select,
               resource_refs: resource_refs
             } = DataView.unfold(data_view)

      assert resource_refs == %{
               from_qid => %{
                 type: "data_structure",
                 id: from_resource_id,
                 alias: "from_alias"
               },
               join_qid => %{
                 type: "data_view",
                 id: nested_data_view.id,
                 alias: "join_alias"
               }
             }

      assert select == %{
               __type__: "select",
               fields: [
                 %{
                   __type__: "select_field",
                   alias: "select_field",
                   expression: %{
                     __type__: "constant",
                     type: "string",
                     value: "foo"
                   }
                 }
               ],
               resource_ref: select_queryable_id
             }

      assert [from, join, where] = queryables

      assert from == %{__type__: "from", resource_ref: from_qid, resource: nil}

      assert where == %{
               __type__: "where",
               clauses: [
                 [
                   %{
                     __type__: "function",
                     type: "boolean",
                     name: "and",
                     args: [
                       %{
                         __type__: "function_arg",
                         name: "arg1",
                         expression: %{
                           __type__: "constant",
                           type: "boolean",
                           value: "true"
                         }
                       },
                       %{
                         __type__: "function_arg",
                         name: "arg2",
                         expression: %{
                           __type__: "constant",
                           type: "boolean",
                           value: "false"
                         }
                       }
                     ]
                   }
                 ]
               ]
             }

      assert %{
               __type__: "join",
               type: "inner",
               resource: nested_dataview,
               clauses: join_on
             } = join

      assert join_on == [
               [
                 %{
                   __type__: "function",
                   type: "boolean",
                   name: "eq",
                   args: [
                     %{
                       __type__: "function_arg",
                       name: "arg1",
                       expression: %{
                         __type__: "field",
                         id: field_id1,
                         name: "field_#{field_id1}",
                         parent_id: from_qid
                       }
                     },
                     %{
                       __type__: "function_arg",
                       name: "arg2",
                       expression: %{
                         __type__: "field",
                         id: field_id2,
                         name: "field_#{field_id2}",
                         parent_id: join_qid
                       }
                     }
                   ]
                 }
               ]
             ]

      # Assert nested data view
      assert %{
               __type__: "data_view",
               queryables: queryables,
               select: select,
               resource_refs: resource_refs
             } = nested_dataview

      assert resource_refs == %{
               nested_from_qid => %{
                 type: "data_structure",
                 id: nested_from_resource_id,
                 alias: "nested_from_alias"
               }
             }

      assert select == %{
               __type__: "select",
               fields: [
                 %{
                   __type__: "select_field",
                   alias: "nested_select_field",
                   expression: %{
                     __type__: "constant",
                     type: "string",
                     value: "nested_foo"
                   }
                 }
               ],
               resource_ref: nested_select_id
             }

      assert queryables == [%{__type__: "from", resource_ref: nested_from_qid, resource: nil}]
    end
  end
end
