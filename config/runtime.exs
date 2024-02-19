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

  config :td_qx, TdQx.Repo,
    username: System.fetch_env!("DB_USER"),
    password: System.fetch_env!("DB_PASSWORD"),
    database: System.fetch_env!("DB_NAME"),
    hostname: System.fetch_env!("DB_HOST"),
    port: System.get_env("DB_PORT", "5432") |> String.to_integer(),
    pool_size: System.get_env("DB_POOL_SIZE", "4") |> String.to_integer(),
    timeout: System.get_env("DB_TIMEOUT_MILLIS", "15000") |> String.to_integer(),
    ssl: System.get_env("DB_SSL", "") |> String.downcase() == "true",
    ssl_opts: [
      cacertfile: System.get_env("DB_SSL_CACERTFILE", ""),
      verify:
        System.get_env("DB_SSL_VERIFY", "verify_none") |> String.downcase() |> String.to_atom(),
      server_name_indication: System.get_env("DB_HOST") |> to_charlist(),
      certfile: System.get_env("DB_SSL_CLIENT_CERT", ""),
      keyfile: System.get_env("DB_SSL_CLIENT_KEY", ""),
      versions: [
        System.get_env("DB_SSL_VERSION", "tlsv1.2") |> String.downcase() |> String.to_atom()
      ]
    ],
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
end
