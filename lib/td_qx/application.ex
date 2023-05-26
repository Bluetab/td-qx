defmodule TdQx.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    env = Application.get_env(:td_qx, :env)

    children =
      [
        TdQx.Repo,
        TdQxWeb.Endpoint
      ] ++ workers(env)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TdQx.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp workers(:test), do: []

  defp workers(_env) do
    topologies = Application.get_env(:libcluster, :topologies)
    [
      {Cluster.Supervisor, [topologies, [name: TdQx.ClusterSupervisor]]}
    ]
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TdQxWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
