defmodule TdQx.Scores.ElasticDocument do
  @moduledoc "Elasticsearch mapping and aggregation definition for QualityControl"

  alias Elasticsearch.Document
  alias TdCache.UserCache
  alias TdCore.Search.ElasticDocument
  alias TdCore.Search.ElasticDocumentProtocol
  alias TdQx.Scores.ScoreGroup

  defimpl Document, for: ScoreGroup do
    use ElasticDocument

    alias TdDfLib.Content

    @score_group_keys [
      :id,
      :df_type,
      :inserted_at
    ]

    @impl Document
    def id(%ScoreGroup{id: id}), do: id

    @impl Document
    def routing(_), do: false

    @impl Document
    def encode(score_group) do
      template = Map.get(score_group, :template)

      dynamic_content =
        score_group
        |> Map.get(:dynamic_content)
        |> Format.search_values(template)
        |> case do
          content when is_map(content) ->
            Content.to_legacy(content)

          content ->
            content
        end

      created_by = get_user(score_group.created_by)

      score_group
      |> Map.take(@score_group_keys)
      |> Map.put(:dynamic_content, dynamic_content)
      |> Map.put(:created_by, created_by)
    end

    defp get_user(user_id) do
      case UserCache.get(user_id) do
        {:ok, nil} ->
          %{}

        {:ok, user} ->
          %{id: user.id, user_name: user.user_name, full_name: user.full_name}
      end
    end
  end

  defimpl ElasticDocumentProtocol, for: ScoreGroup do
    use ElasticDocument

    def mappings(_) do
      content_mappings = %{properties: get_dynamic_mappings("qxe")}

      properties = %{
        id: %{type: "long", index: false},
        df_type: %{type: "keyword", fields: @raw_sort, null_value: ""},
        dynamic_content: content_mappings,
        created_by: %{
          type: "object",
          properties: %{
            id: %{type: "long", index: false},
            user_name: %{type: "keyword", fields: @raw},
            full_name: %{type: "text", fields: @raw}
          }
        },
        inserted_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"}
      }

      settings =
        :score_groups
        |> Cluster.setting()
        |> apply_lang_settings()

      %{
        mappings: %{properties: properties},
        settings: settings
      }
    end

    def aggregations(_) do
      merged_aggregations("score_groups")
    end

    def query_data(_) do
      content_schema = Templates.content_schema_for_scope("qxe")

      %{
        query: %{},
        aggs: merged_aggregations(content_schema)
      }
    end

    defp native_aggregations do
      %{
        "created_by" => %{
          terms: %{field: "created_by.user_name", size: Cluster.get_size_field("created_by")}
        }
      }
    end

    defp merged_aggregations(scope_or_schema) do
      native_aggregations = native_aggregations()
      merge_dynamic_aggregations(native_aggregations, scope_or_schema, "dynamic_content")
    end
  end
end
