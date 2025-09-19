import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/td_qx start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :td_qx, TdQxWeb.Endpoint, server: true
end

config :td_cluster, groups: [:qx]

if config_env() == :prod do
  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  get_ssl_option = fn env_var, option_key ->
    if System.get_env("DB_SSL", "") |> String.downcase() == "true" do
      case System.get_env(env_var, "") do
        "" -> []
        "nil" -> []
        value -> [{option_key, value}]
      end
    else
      []
    end
  end

  optional_db_ssl_options_cacertfile = get_ssl_option.("DB_SSL_CACERTFILE", :cacertfile)
  optional_db_ssl_options_certfile = get_ssl_option.("DB_SSL_CLIENT_CERT", :certfile)
  optional_db_ssl_options_keyfile = get_ssl_option.("DB_SSL_CLIENT_KEY", :keyfile)

  config :td_qx, TdQx.Repo,
    username: System.fetch_env!("DB_USER"),
    password: System.fetch_env!("DB_PASSWORD"),
    database: System.fetch_env!("DB_NAME"),
    hostname: System.fetch_env!("DB_HOST"),
    port: System.get_env("DB_PORT", "5432") |> String.to_integer(),
    pool_size: System.get_env("DB_POOL_SIZE", "4") |> String.to_integer(),
    timeout: System.get_env("DB_TIMEOUT_MILLIS", "15000") |> String.to_integer(),
    ssl: System.get_env("DB_SSL", "") |> String.downcase() == "true",
    ssl_opts:
      [
        verify:
          System.get_env("DB_SSL_VERIFY", "verify_none") |> String.downcase() |> String.to_atom(),
        server_name_indication: System.get_env("DB_HOST") |> to_charlist(),
        versions: [
          System.get_env("DB_SSL_VERSION", "tlsv1.2") |> String.downcase() |> String.to_atom()
        ]
      ] ++
        optional_db_ssl_options_cacertfile ++
        optional_db_ssl_options_certfile ++
        optional_db_ssl_options_keyfile,
    socket_options: maybe_ipv6

  config :td_core, TdCore.Auth.Guardian, secret_key: System.fetch_env!("GUARDIAN_SECRET_KEY")

  config :td_cache,
    redis_host: System.fetch_env!("REDIS_HOST"),
    port: System.get_env("REDIS_PORT", "6379") |> String.to_integer(),
    password: System.get_env("REDIS_PASSWORD")

  config :td_core, TdCore.Search.Cluster, url: System.fetch_env!("ES_URL")

  with username when not is_nil(username) <- System.get_env("ES_USERNAME"),
       password when not is_nil(password) <- System.get_env("ES_PASSWORD") do
    config :td_dd, TdCore.Search.Cluster,
      username: username,
      password: password
  end

  with api_key when not is_nil(api_key) <- System.get_env("ES_API_KEY") do
    config :td_core, TdCore.Search.Cluster,
      default_headers: [{"Authorization", "ApiKey #{api_key}"}]
  end
end

optional_ssl_options =
  case System.get_env("ES_SSL") do
    "true" ->
      cacertfile =
        case System.get_env("ES_SSL_CACERTFILE", "generated") do
          "generated" -> :certifi.cacertfile()
          file -> file
        end

      [
        ssl: [
          cacertfile: cacertfile,
          verify:
            System.get_env("ES_SSL_VERIFY", "verify_none")
            |> String.downcase()
            |> String.to_atom()
        ]
      ]

    _ ->
      []
  end

elastic_default_options =
  [
    timeout: System.get_env("ES_TIMEOUT", "5000") |> String.to_integer(),
    recv_timeout: System.get_env("ES_RECV_TIMEOUT", "40000") |> String.to_integer()
  ] ++ optional_ssl_options

config :td_core, TdCore.Search.Cluster,
  # If the variable delete_existing_index is set to false,
  # it will not be deleted in the case that there is no index in the hot swap process."
  delete_existing_index: System.get_env("DELETE_EXISTING_INDEX", "true") |> String.to_atom(),
  forcemerge_options: [
    wait_for_completion: System.get_env("ES_WAIT_FOR_COMPLETION", "nil") |> String.to_atom(),
    max_num_segments: System.get_env("ES_MAX_NUM_SEGMENTS", "5") |> String.to_integer()
  ],
  default_options: elastic_default_options,
  default_settings: %{
    "number_of_shards" => System.get_env("ES_SHARDS", "1") |> String.to_integer(),
    "number_of_replicas" => System.get_env("ES_REPLICAS", "1") |> String.to_integer(),
    "refresh_interval" => System.get_env("ES_REFRESH_INTERVAL", "5s"),
    "max_result_window" => System.get_env("ES_MAX_RESULT_WINDOW", "10000") |> String.to_integer(),
    "index.indexing.slowlog.threshold.index.warn" =>
      System.get_env("ES_INDEXING_SLOWLOG_THRESHOLD_WARN", "10s"),
    "index.indexing.slowlog.threshold.index.info" =>
      System.get_env("ES_INDEXING_SLOWLOG_THRESHOLD_INFO", "5s"),
    "index.indexing.slowlog.threshold.index.debug" =>
      System.get_env("ES_INDEXING_SLOWLOG_THRESHOLD_DEBUG", "2s"),
    "index.indexing.slowlog.threshold.index.trace" =>
      System.get_env("ES_INDEXING_SLOWLOG_THRESHOLD_TRACE", "500ms"),
    # "index.indexing.slowlog.level" => System.get_env("ES_INDEXING_SLOWLOG_LEVEL", "info"),
    "index.indexing.slowlog.source" => System.get_env("ES_INDEXING_SLOWLOG_SOURCE", "1000"),
    "index.mapping.total_fields.limit" => System.get_env("ES_MAPPING_TOTAL_FIELDS_LIMIT", "3000")
  }

config :td_core, TdCore.Search.Cluster,
  indexes: [
    quality_control_versions: [
      bulk_page_size:
        System.get_env("BULK_PAGE_SIZE_QUALITY_CONTROL_VERSIONS", "5000") |> String.to_integer()
    ],
    score_groups: [
      bulk_page_size: System.get_env("BULK_PAGE_SIZE_SCORE_GROUPS", "5000") |> String.to_integer()
    ]
  ]

config :td_core, TdCore.Search.Cluster,
  # Aggregations default
  aggregations: %{
    "domain" => System.get_env("AGG_DOMAIN_SIZE", "500") |> String.to_integer(),
    "user" => System.get_env("AGG_USER_SIZE", "500") |> String.to_integer(),
    "system" => System.get_env("AGG_SYSTEM_SIZE", "500") |> String.to_integer(),
    "default" => System.get_env("AGG_DEFAULT_SIZE", "500") |> String.to_integer(),
    "control_mode.raw" =>
      System.get_env("AGG_CONTROL_MODE_RAW_SIZE", "500") |> String.to_integer(),
    "status" => System.get_env("AGG_STATUS_SIZE", "500") |> String.to_integer(),
    "df_type.raw" => System.get_env("AGG_DF_TYPE_RAW_SIZE", "500") |> String.to_integer(),
    "taxonomy" => System.get_env("AGG_TAXONOMY_SIZE", "500") |> String.to_integer(),
    "active" => System.get_env("AGG_ACTIVE_SIZE", "500") |> String.to_integer(),
    "created_by" => System.get_env("AGG_CREATED_BY_SIZE", "500") |> String.to_integer()
  }
