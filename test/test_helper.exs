{:ok, _} = Application.ensure_all_started(:ex_machina)
ExUnit.start()
Mox.defmock(MockClusterHandler, for: TdCluster.ClusterHandlerBehaviour)
Ecto.Adapters.SQL.Sandbox.mode(TdQx.Repo, :manual)
