defmodule TdQx.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    topologies = [
      example: [
        strategy: Cluster.Strategy.LocalEpmd,
        config: [hosts: [:td_dd, :td_qx]]
      ]
    ]

    children = [
      # Start the Telemetry supervisor
      TdQxWeb.Telemetry,
      # Start the Ecto repository
      TdQx.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: TdQx.PubSub},
      # Start the Endpoint (http/https)
      TdQxWeb.Endpoint,
      # Start a worker by calling: TdQx.Worker.start_link(arg)
      # {TdQx.Worker, arg},
      {Cluster.Supervisor, [topologies, [name: TdQx.ClusterSupervisor]]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TdQx.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TdQxWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
