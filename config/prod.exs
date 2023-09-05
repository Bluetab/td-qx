import Config

# For production, don't forget to configure the url host
# to something meaningful, Phoenix uses this information
# when generating URLs.

# Do not print debug messages in production
config :logger, level: :info

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.

config :td_qx, TdQx.Scheduler,
  jobs: [
    [
      schedule: "@reboot",
      task: {TdQx.Functions, :load_from_file!, ["/app/native_functions.json"]},
      run_strategy: Quantum.RunStrategy.Local
    ]
  ]
