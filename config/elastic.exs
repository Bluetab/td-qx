import Config

config :td_core, TdCore.Search.Cluster,
  # The default URL where Elasticsearch is hosted on your system.
  # Will be overridden by the `ES_URL` environment variable if set.
  url: "http://elastic:9200",

  # If you want to mock the responses of the Elasticsearch JSON API
  # for testing or other purposes, you can inject a different module
  # here. It must implement the Elasticsearch.API behaviour.
  api: Elasticsearch.API.HTTP,

  # The library used for JSON encoding/decoding.
  json_library: Jason,
  aliases: %{
    score_groups: "score_groups",
    quality_control_versions: "quality_control_versions"
  }

config :td_core, TdCore.Search.Cluster,
  indexes: [
    quality_control_versions: [
      template_scope: :qx,
      store: TdQx.Search.Store,
      sources: [TdQx.QualityControls.QualityControlVersion],
      bulk_wait_interval: 0,
      bulk_action: "index",
      settings: %{
        analysis: %{
          analyzer: %{
            default: %{
              type: "custom",
              tokenizer: "split_on_non_word",
              filter: ["lowercase", "asciifolding"]
            },
            exact_analyzer: %{
              type: "custom",
              tokenizer: "split_on_non_word",
              filter: ["lowercase", "asciifolding"]
            }
          },
          normalizer: %{
            sortable: %{type: "custom", char_filter: [], filter: ["lowercase", "asciifolding"]}
          },
          tokenizer: %{
            split_on_non_word: %{
              type: "pattern",
              pattern: "\\W+|_"
            }
          },
          filter: %{
            es_stem: %{
              type: "stemmer",
              language: "light_spanish"
            }
          }
        }
      }
    ],
    score_groups: [
      template_scope: :qxe,
      store: TdQx.Search.Store,
      sources: [TdQx.Scores.ScoreGroup],
      bulk_wait_interval: 0,
      bulk_action: "index",
      settings: %{
        analysis: %{
          analyzer: %{
            default: %{
              type: "custom",
              tokenizer: "split_on_non_word",
              filter: ["lowercase", "asciifolding"]
            },
            exact_analyzer: %{
              type: "custom",
              tokenizer: "split_on_non_word",
              filter: ["lowercase", "asciifolding"]
            }
          },
          normalizer: %{
            sortable: %{type: "custom", char_filter: [], filter: ["lowercase", "asciifolding"]}
          },
          tokenizer: %{
            split_on_non_word: %{
              type: "pattern",
              pattern: "\\W+|_"
            }
          },
          filter: %{
            es_stem: %{
              type: "stemmer",
              language: "light_spanish"
            }
          }
        }
      }
    ]
  ]
