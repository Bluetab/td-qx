defmodule TdQx.QualityControls.ElasticDocument do
  @moduledoc "Elasticsearch mapping and aggregation definition for quality control versions"

  alias Elasticsearch.Document
  alias TdCore.Search.ElasticDocument
  alias TdCore.Search.ElasticDocumentProtocol
  alias TdQx.QualityControls.QualityControlVersion
  alias TdQx.QualityControls.ScoreCriteria
  alias TdQx.QualityControls.ScoreCriterias
  alias TdQx.Scores
  alias TdQx.Scores.Score
  alias TdQx.Scores.ScoreEvent

  defimpl Document, for: QualityControlVersion do
    use ElasticDocument

    @keys [
      :id,
      :name,
      :status,
      :version,
      :df_type,
      :control_mode,
      :inserted_at,
      :updated_at,
      :latest
    ]

    @pending_statuses ScoreEvent.valid_types() -- ["SUCCEEDED"]

    @impl Document
    def id(%QualityControlVersion{id: id}), do: id

    @impl Document
    def routing(_), do: false

    @impl Document
    def encode(%QualityControlVersion{quality_control: quality_control} = version) do
      template = Map.get(version, :template)

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
      |> Map.take(@keys)
      |> Map.put(:ngram_name, version.name)
      |> Map.put(:quality_control_id, quality_control.id)
      |> Map.put(:domain_ids, quality_control.domain_ids)
      |> Map.put(:dynamic_content, dynamic_content)
      |> Map.put(:active, quality_control.active)
      |> with_score_criteria(version)
      |> with_latest_score(version)
    end

    defp with_score_criteria(document, %QualityControlVersion{
           score_criteria: %ScoreCriteria{
             count: %ScoreCriterias.Count{goal: goal, maximum: maximum}
           }
         }) do
      Map.put(document, :score_criteria, %{goal: goal, maximum: maximum})
    end

    defp with_score_criteria(document, %QualityControlVersion{
           score_criteria: %ScoreCriteria{
             deviation: %ScoreCriterias.Deviation{goal: goal, maximum: maximum}
           }
         }) do
      deviation = %{goal: Float.round(goal, 2), maximum: Float.round(maximum, 2)}
      Map.put(document, :score_criteria, deviation)
    end

    defp with_score_criteria(document, %QualityControlVersion{
           score_criteria: %ScoreCriteria{
             percentage: %ScoreCriterias.Percentage{minimum: minimum, goal: goal}
           }
         }) do
      percentage = %{goal: Float.round(goal, 2), minimum: Float.round(minimum, 2)}
      Map.put(document, :score_criteria, percentage)
    end

    defp with_score_criteria(document, %QualityControlVersion{
           score_criteria: %ScoreCriteria{
             error_count: %ScoreCriterias.ErrorCount{goal: goal, maximum: maximum}
           }
         }) do
      error_count = %{goal: Float.round(goal, 2), maximum: Float.round(maximum, 2)}
      Map.put(document, :score_criteria, error_count)
    end

    defp with_score_criteria(document, _other), do: document

    defp with_latest_score(version, %QualityControlVersion{} = qcv) do
      score = Scores.get_latest_score(qcv)

      with_latest_score(version, qcv, score)
    end

    defp with_latest_score(version, _qcv, %Score{status: status})
         when status in @pending_statuses do
      Map.put(version, :latest_score, %{result_message: nil, status: String.downcase(status)})
    end

    defp with_latest_score(
           version,
           %QualityControlVersion{} = quality_control_version,
           %Score{} = score
         ) do
      score_content_attrs = Scores.score_content(quality_control_version, score)

      latest_score =
        Map.merge(
          %{
            status: String.downcase(score.status || ""),
            type: score.score_type,
            executed_at: score.execution_timestamp
          },
          score_content_attrs
        )

      Map.put(version, :latest_score, latest_score)
    end

    defp with_latest_score(version, %QualityControlVersion{}, _) do
      Map.put(version, :latest_score, %{result_message: nil})
    end
  end

  defimpl ElasticDocumentProtocol, for: QualityControlVersion do
    use ElasticDocument

    @search_fields ~w(ngram_name*^3)

    def mappings(_) do
      content_mappings = %{properties: get_dynamic_mappings("quality_control")}

      properties = %{
        id: %{type: "long", index: false},
        quality_control_id: %{type: "long", index: false},
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
        inserted_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
        score_criteria: %{
          properties: %{
            deviation: %{
              properties: %{
                goal: %{type: "text", index: false},
                maximum: %{type: "text", index: false}
              }
            },
            percentage: %{
              properties: %{
                goal: %{type: "text", index: false},
                minimum: %{type: "text", index: false}
              }
            },
            count: %{
              properties: %{
                goal: %{type: "text", index: false},
                maximum: %{type: "text", index: false}
              }
            },
            error_count: %{
              properties: %{
                goal: %{type: "text", index: false},
                maximum: %{type: "text", index: false}
              }
            }
          }
        },
        latest_score: %{
          properties: %{
            status: %{
              type: "keyword",
              fields: %{sort: %{type: "keyword", normalizer: "sortable"}},
              null_value: ""
            },
            executed_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
            type: %{
              type: "keyword",
              fields: %{sort: %{type: "keyword", normalizer: "sortable"}},
              null_value: ""
            },
            count_content: %{properties: %{count: %{type: "long", index: false}}},
            ratio_content: %{
              properties: %{
                total_count: %{type: "long", index: false},
                validation_count: %{type: "long", index: false}
              }
            },
            result_message: %{
              type: "keyword",
              fields: %{sort: %{type: "keyword", normalizer: "sortable"}},
              null_value: "not_executed"
            },
            result: %{type: "text", fields: %{sort: %{type: "keyword", normalizer: "sortable"}}}
          }
        }
      }

      settings =
        :quality_control_versions
        |> Cluster.setting()
        |> apply_lang_settings()

      %{mappings: %{properties: properties}, settings: settings}
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
        "active" => %{terms: %{field: "active", size: Cluster.get_size_field("active")}},
        "latest_score.result_message" => %{
          terms: %{
            field: "latest_score.result_message",
            size: Cluster.get_size_field("latest_score.result_message")
          }
        },
        "latest_score.status" => %{
          terms: %{
            field: "latest_score.status",
            size: Cluster.get_size_field("latest_score.status")
          }
        },
        "latest_score.type" => %{
          terms: %{
            field: "latest_score.type",
            size: Cluster.get_size_field("latest_score.type")
          }
        }
      }
    end

    defp merged_aggregations(scope_or_schema) do
      native_aggregations = native_aggregations()
      merge_dynamic_aggregations(native_aggregations, scope_or_schema, "content")
    end
  end
end
