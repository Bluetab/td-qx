# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :td_qx, :env, Mix.env()
config :td_cluster, :env, Mix.env()
config :td_core, :env, Mix.env()

config :td_qx,
  ecto_repos: [TdQx.Repo]

config :td_df_lib, :templates_module, TdCluster.Cluster.TdDf.Templates

# Configures the endpoint
config :td_qx, TdQxWeb.Endpoint,
  http: [port: 4010],
  url: [host: "localhost"],
  render_errors: [
    formats: [json: TdQxWeb.ErrorJSON],
    layout: false
  ],
  live_view: [signing_salt: "ZOlKIPdj"]

config :td_core, TdCore.Auth.Guardian,
  allowed_algos: ["HS512"],
  issuer: "tdauth",
  aud: "truedat",
  ttl: {1, :hours},
  secret_key: "SuperSecretTruedat"

config :bodyguard, default_error: :forbidden

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :td_qx, TdQx.Scheduler,
  jobs: [
    [
      schedule: "@reboot",
      task: {TdQx.Functions, :load_from_file!, ["priv/repo/native_functions.json"]},
      run_strategy: Quantum.RunStrategy.Local
    ]
  ]

# Import Elasticsearch config
import_config "elastic.exs"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
