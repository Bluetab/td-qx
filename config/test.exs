import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :td_qx, TdQx.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "postgres",
  database: "td_qx_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 1

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :td_qx, TdQxWeb.Endpoint, server: false

config :td_cluster, :cluster_handler, MockClusterHandler

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :td_cache, redis_host: "redis", port: 6380

config :td_qx, TdQx.Scheduler, jobs: []
