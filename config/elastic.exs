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
    quality_controls: "quality_controls"
  }

config :td_core, TdCore.Search.Cluster,
  indexes: [
    quality_controls: [
      store: TdQx.Search.Store,
      sources: [TdQx.QualityControls.QualityControl],
      bulk_wait_interval: 0,
      bulk_action: "index",
      settings: %{
        analysis: %{
          analyzer: %{
            ngram: %{
              filter: ["lowercase", "asciifolding"],
              tokenizer: "ngram"
            }
          },
          normalizer: %{
            sortable: %{type: "custom", char_filter: [], filter: ["lowercase", "asciifolding"]}
          },
          tokenizer: %{
            ngram: %{
              type: "ngram",
              min_gram: 3,
              max_gram: 3,
              token_chars: ["letter", "digit"]
            }
          }
        }
      }
    ]
  ]
