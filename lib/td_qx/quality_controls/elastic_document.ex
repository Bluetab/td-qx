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
      :df_type,
      :control_mode,
      :inserted_at,
      :updated_at
    ]

    @impl Document
    def id(%QualityControl{id: id}), do: id

    @impl Document
    def routing(_), do: false

    @impl Document
    def encode(%{latest_version: version} = quality_control) do
      template = Map.get(quality_control, :template)

      dynamic_content =
        version
        |> Map.get(:dynamic_content)
        |> Format.search_values(template)
        |> case do
          content when is_map(content) ->
            Enum.into(content, %{}, fn {key, %{"value" => value}} -> {key, value} end)

          content ->
            content
        end

      version
      |> Map.take(@version_keys)
      |> Map.put(:ngram_name, version.name)
      |> Map.put(:version_id, version.id)
      |> Map.put(:id, quality_control.id)
      |> Map.put(:domain_ids, quality_control.domain_ids)
      |> Map.put(:dynamic_content, dynamic_content)
      |> Map.put(:active, quality_control.active)
    end
  end

  defimpl ElasticDocumentProtocol, for: QualityControl do
    use ElasticDocument

    @search_fields ~w(ngram_name*^3)

    def mappings(_) do
      content_mappings = %{properties: get_dynamic_mappings("quality_control")}

      properties = %{
        id: %{type: "long", index: false},
        version_id: %{type: "long", index: false},
        active: %{type: "boolean"},
        domain_ids: %{type: "long"},
        name: %{type: "text", fields: @raw_sort},
        ngram_name: %{type: "search_as_you_type"},
        version: %{type: "short"},
        control_mode: %{type: "keyword", fields: @raw_sort},
        status: %{type: "keyword"},
        df_type: %{type: "keyword", fields: @raw_sort, null_value: ""},
        dynamic_content: content_mappings,
        updated_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
        inserted_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"}
      }

      settings =
        :quality_controls
        |> Cluster.setting()
        |> apply_lang_settings()

      %{
        mappings: %{properties: properties},
        settings: settings
      }
    end

    def aggregations(_) do
      merged_aggregations("quality_control")
    end

    def query_data(_) do
      content_schema = Templates.content_schema_for_scope("quality_control")

      %{
        fields: @search_fields,
        aggs: merged_aggregations(content_schema)
      }
    end

    defp native_aggregations do
      %{
        "control_mode.raw" => %{
          terms: %{
            field: "control_mode.raw",
            size: Cluster.get_size_field("control_mode.raw")
          }
        },
        "status" => %{terms: %{field: "status", size: Cluster.get_size_field("status")}},
        "df_type.raw" => %{
          terms: %{field: "df_type.raw", size: Cluster.get_size_field("df_type.raw")}
        },
        "taxonomy" => %{terms: %{field: "domain_ids", size: Cluster.get_size_field("taxonomy")}},
        "active" => %{terms: %{field: "active", size: Cluster.get_size_field("active")}}
      }
    end

    defp merged_aggregations(scope_or_schema) do
      native_aggregations = native_aggregations()
      merge_dynamic_aggregations(native_aggregations, scope_or_schema, "content")
    end
  end
end
