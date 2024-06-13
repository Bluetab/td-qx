defmodule TdQx.QualityControls.ElasticDocument do
  @moduledoc "Elasticsearch mapping and aggregation definition for QualityControl"

  alias Elasticsearch.Document
  alias TdCore.Search.ElasticDocument
  alias TdCore.Search.ElasticDocumentProtocol
  alias TdQx.QualityControls.QualityControl

  defimpl Document, for: QualityControl do
    use ElasticDocument

    @version_keys [
      :name,
      :status,
      :version,
      :df_content,
      :df_type,
      :result_type,
      :inserted_at,
      :updated_at
    ]

    @impl Document
    def id(%QualityControl{id: id}), do: id

    @impl Document
    def routing(_), do: false

    @impl Document
    def encode(%{latest_version: version} = quality_control) do
      df_content =
        version
        |> Map.get(:df_content)
        |> Format.search_values(quality_control.template)

      version
      |> Map.take(@version_keys)
      |> Map.put(:id, quality_control.id)
      |> Map.put(:domain_ids, quality_control.domain_ids)
      |> Map.put(:df_content, df_content)
    end
  end

  defimpl ElasticDocumentProtocol, for: QualityControl do
    use ElasticDocument

    def mappings(_) do
      content_mappings = %{type: "object", properties: get_dynamic_mappings("quality_control")}

      properties = %{
        id: %{type: "long", index: false},
        name: %{type: "text", fields: @raw_sort_ngram},
        domain_ids: %{type: "long"},
        version: %{type: "short"},
        result_type: %{type: "keyword", fields: @raw_sort},
        status: %{type: "keyword"},
        df_type: %{type: "keyword", fields: @raw_sort, null_value: ""},
        df_content: content_mappings,
        updated_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
        inserted_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"}
      }

      settings = Cluster.setting(:quality_controls)

      %{
        mappings: %{properties: properties},
        settings: settings
      }
    end

    def aggregations(_) do
      %{
        "result_type.raw" => %{
          terms: %{field: "result_type.raw", size: Cluster.get_size_field("result_type.raw")}
        },
        "status" => %{terms: %{field: "status", size: Cluster.get_size_field("status")}},
        "df_type.raw" => %{
          terms: %{field: "df_type.raw", size: Cluster.get_size_field("df_type.raw")}
        },
        "taxonomy" => %{terms: %{field: "domain_ids", size: Cluster.get_size_field("taxonomy")}}
      }
      |> merge_dynamic_fields("quality_control")
    end
  end
end
