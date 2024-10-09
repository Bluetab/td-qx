defmodule TdQx.Expressions.QualityControlTransformerTest do
  alias TdQx.QualityControls
  use TdQx.DataCase

  import ExUnit.CaptureLog
  alias TdCluster.TestHelpers.TdDdMock
  alias TdQx.DataViews.DataView
  alias TdQx.ExpressionFactory
  alias TdQx.QualityControlTransformer
  alias TdQx.QueryableFactory

  describe "quality_controls_queries/1" do
    test "returns queries for various QualityControls" do
      source_id = 10

      insert(:quality_control_version,
        status: "published",
        quality_control: insert(:quality_control, source_id: source_id),
        resource: build(:resource, type: "data_structure", id: 888)
      )

      insert(:quality_control_version,
        status: "published",
        quality_control: insert(:quality_control, source_id: source_id),
        resource: build(:resource, type: "data_structure", id: 999)
      )

      quality_controls =
        source_id
        |> QualityControls.list_quality_controls_by_source_id()
        |> QualityControlTransformer.quality_controls_queries()

      assert [
               %{
                 queries: [
                   %{
                     __type__: "query",
                     action: "count",
                     resource: %{queryables: [%{__type__: "from"}]}
                   },
                   %{
                     __type__: "query",
                     action: "count",
                     resource: %{queryables: [%{__type__: "from"}, %{__type__: "where"}]}
                   }
                 ]
               },
               %{
                 queries: [
                   %{
                     __type__: "query",
                     action: "count",
                     resource: %{queryables: [%{__type__: "from"}]}
                   },
                   %{
                     __type__: "query",
                     action: "count",
                     resource: %{queryables: [%{__type__: "from"}, %{__type__: "where"}]}
                   }
                 ]
               }
             ] = quality_controls
    end

    test "filters not published versions" do
      source_id = 10

      insert(:quality_control_version,
        status: "published",
        quality_control: insert(:quality_control, source_id: source_id),
        resource: build(:resource, type: "data_structure", id: 888)
      )

      insert(:quality_control_version,
        status: "draft",
        quality_control: insert(:quality_control, source_id: source_id),
        resource: build(:resource, type: "data_structure", id: 888)
      )

      quality_controls =
        source_id
        |> QualityControls.list_quality_controls_by_source_id()
        |> QualityControlTransformer.quality_controls_queries()

      assert [
               %{
                 queries: [
                   %{
                     __type__: "query",
                     action: "count",
                     resource: %{queryables: [%{__type__: "from"}]}
                   },
                   %{
                     __type__: "query",
                     action: "count",
                     resource: %{queryables: [%{__type__: "from"}, %{__type__: "where"}]}
                   }
                 ]
               }
             ] = quality_controls
    end
  end

  describe "queries_from/1" do
    test "returns queries for QualityControl when resource is data view" do
      resource_id = 10
      resource = build(:resource, type: "data_structure", id: resource_id)
      from_id = 20
      from = QueryableFactory.from(resource, alias: "from_alias", id: from_id)

      %{id: select_queryable_id} =
        select =
        QueryableFactory.select([
          [alias: "select_field", expression: ExpressionFactory.constant("string", "foo")]
        ])

      data_view = insert(:data_view, queryables: [from], select: select)

      expression = ExpressionFactory.constant("boolean", "true")
      clause = build(:clause, expressions: [expression])

      quality_control_version =
        insert(:quality_control_version,
          resource: build(:resource, type: "data_view", id: data_view.id),
          validation: [clause],
          quality_control: insert(:quality_control)
        )

      [
        population_query,
        validation_query
      ] = QualityControlTransformer.queries_from(quality_control_version)

      %{
        __type__: "query",
        action: "count",
        resource: %{
          __type__: "data_view",
          queryables: [population_from],
          resource_refs: population_resource_refs
        }
      } = population_query

      %{
        __type__: "query",
        action: "count",
        resource: %{
          __type__: "data_view",
          queryables: [validation_from, validation_where],
          resource_refs: validation_resource_refs
        }
      } = validation_query

      assert population_from == validation_from

      assert validation_from == %{
               __type__: "from",
               resource_ref: 0,
               resource: %{
                 __type__: "data_view",
                 queryables: [%{__type__: "from", resource_ref: from_id, resource: nil}],
                 select: %{
                   __type__: "select",
                   fields: [
                     %{
                       __type__: "select_field",
                       alias: "select_field",
                       expression: %{__type__: "constant", type: "string", value: "foo"}
                     }
                   ],
                   resource_ref: select_queryable_id
                 },
                 resource_refs: %{
                   from_id => %{
                     type: "data_structure",
                     id: resource_id,
                     alias: "from_alias"
                   }
                 }
               }
             }

      assert population_resource_refs == validation_resource_refs

      assert validation_resource_refs == %{
               0 => %{
                 alias: nil,
                 id: data_view.id,
                 type: "data_view"
               }
             }

      assert validation_where == %{
               __type__: "where",
               clauses: [
                 [
                   %{__type__: "constant", type: "boolean", value: "true"}
                 ]
               ]
             }
    end
  end

  describe "build_resources_lookup/1" do
    test "generates enriched" do
      from = QueryableFactory.from(build(:resource, type: "data_structure", id: 11))
      dv1 = insert(:data_view, queryables: [from])

      from = QueryableFactory.from(build(:resource, type: "reference_dataset", id: 22))
      dv2 = insert(:data_view, queryables: [from])

      from = QueryableFactory.from(build(:resource, type: "data_structure", id: 33))
      nested_dv = insert(:data_view, queryables: [from])

      from = QueryableFactory.from(build(:resource, type: "data_structure", id: 44))
      resource = build(:resource, type: "data_view", id: nested_dv.id)
      join = QueryableFactory.join("inner", resource, [])
      dv3 = insert(:data_view, queryables: [from, join])

      from = QueryableFactory.from(build(:resource, type: "data_view", id: dv3.id))
      resource = build(:resource, type: "data_view", id: dv1.id)
      join = QueryableFactory.join("inner", resource, [])
      dv4 = insert(:data_view, queryables: [from, join])

      TdDdMock.get_latest_structure_version(
        &Mox.expect/4,
        11,
        {:ok, %{name: "ds11", metadata: %{}}}
      )

      TdDdMock.get_reference_dataset(
        &Mox.expect/4,
        22,
        {:ok, %{name: "rds_22", headers: ["foo"], rows: []}}
      )

      TdDdMock.get_latest_structure_version(
        &Mox.expect/4,
        44,
        {:ok, %{name: "ds44", metadata: %{}}}
      )

      TdDdMock.get_latest_structure_version(
        &Mox.expect/4,
        33,
        {:ok, %{name: "ds33", metadata: %{}}}
      )

      result =
        [dv1, dv2, dv3, dv4]
        |> Enum.map(&%{resource: DataView.unfold(&1)})
        |> QualityControlTransformer.build_resources_lookup()

      assert result == %{
               "data_structure:11" => %{id: 11, metadata: %{}, name: "ds11"},
               "data_structure:33" => %{id: 33, metadata: %{}, name: "ds33"},
               "data_structure:44" => %{id: 44, metadata: %{}, name: "ds44"},
               "reference_dataset:22" => %{
                 headers: ["foo"],
                 id: 22,
                 name: "rds_22",
                 rows: []
               }
             }
    end

    test "handles fail to fetch structure" do
      from = QueryableFactory.from(build(:resource, type: "data_structure", id: 11))
      dv1 = insert(:data_view, queryables: [from])

      TdDdMock.get_latest_structure_version(
        &Mox.expect/4,
        11,
        :error
      )

      {result, log} =
        with_log(fn ->
          QualityControlTransformer.build_resources_lookup([%{resource: DataView.unfold(dv1)}])
        end)

      assert result == %{"data_structure:11" => %{error: "error loading DataStructure"}}

      assert log =~
               "[warning] Failed to enrich %DataStructure{id: 11} from cluster"
    end
  end
end
