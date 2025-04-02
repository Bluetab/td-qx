defmodule TdQx.QualityControlTransformer do
  @moduledoc """
  Transforms a quality control to a query-like format consumable from
  external contexts.
  """
  alias TdCluster.Cluster.TdDd
  alias TdQx.DataViews.DataView
  alias TdQx.DataViews.Queryable
  alias TdQx.DataViews.QueryableProperties
  alias TdQx.DataViews.QueryableProperties.From
  alias TdQx.DataViews.QueryableProperties.Where
  alias TdQx.QualityControls.QualityControlVersion

  require Logger

  def enrich_scores_queries(scores) do
    Enum.map(scores, fn
      %{
        quality_control_version: %QualityControlVersion{} = version
      } = score ->
        %{
          score
          | quality_control_version: %{version | queries: queries_from(version)}
        }

      score ->
        score
    end)
  end

  def enrich_quality_controls_queries(quality_control_versions) do
    quality_control_versions
    |> Enum.map(fn
      %QualityControlVersion{} = version ->
        %{version | queries: queries_from(version)}

      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  def queries_from(%TdQx.QualityControls.QualityControlVersion{
        control_mode: "count",
        control_properties: %{count: %{errors_resource: resource}}
      }) do
    from = %Queryable{
      type: "from",
      id: 0,
      properties: %QueryableProperties{
        from: %From{resource: resource}
      }
    }

    [
      %{
        query_ref: "count",
        __type__: "query",
        resource: DataView.unfold(%DataView{queryables: [from]}),
        action: "count"
      }
    ]
  end

  def queries_from(%TdQx.QualityControls.QualityControlVersion{
        control_mode: mode,
        control_properties: %{ratio: %{resource: resource, validation: clauses}}
      })
      when mode in ["deviation", "percentage"] do
    from = %Queryable{
      type: "from",
      id: 0,
      properties: %QueryableProperties{
        from: %From{resource: resource}
      }
    }

    where = %Queryable{
      type: "where",
      id: 1,
      properties: %QueryableProperties{
        where: %Where{clauses: clauses}
      }
    }

    [
      %{
        query_ref: "total_count",
        __type__: "query",
        resource: DataView.unfold(%DataView{queryables: [from]}),
        action: "count"
      },
      %{
        query_ref: "validation_count",
        __type__: "query",
        resource: DataView.unfold(%DataView{queryables: [from, where]}),
        action: "count"
      }
    ]
  end

  def build_resources_lookup(queries) do
    %{queryables: queries}
    |> accumulate_resources()
    |> Enum.uniq()
    |> Enum.filter(fn {type, _} -> type in ["reference_dataset", "data_structure"] end)
    |> Enum.into(%{}, &fetch_resource/1)
  end

  defp accumulate_resources(%{queryables: queryables}) do
    Enum.flat_map(queryables, fn
      %{resource: %{resource_refs: refs} = resource} ->
        Enum.map(refs, fn {_, %{id: id, type: type}} -> {type, id} end) ++
          accumulate_resources(resource)

      _ ->
        []
    end)
  end

  defp accumulate_resources(_), do: []

  defp fetch_resource({"data_structure", id}) do
    resource =
      case TdDd.get_latest_structure_version(id) do
        {:ok, %{name: name, metadata: metadata}} ->
          %{
            id: id,
            name: name,
            metadata: metadata
          }

        _ ->
          Logger.warning("Failed to enrich %DataStructure{id: #{id}} from cluster")
          %{error: "error loading DataStructure"}
      end

    {"data_structure:#{id}", resource}
  end

  defp fetch_resource({"reference_dataset", id}) do
    resource =
      case TdDd.get_reference_dataset(id) do
        {:ok, %{name: name, headers: headers, rows: rows}} ->
          %{
            id: id,
            name: name,
            headers: headers,
            rows: rows
          }

        _ ->
          Logger.warning("Failed to enrich %ReferenceDataset{id: #{id}} from cluster")
          %{error: "error loading ReferenceDataset"}
      end

    {"reference_dataset:#{id}", resource}
  end
end
