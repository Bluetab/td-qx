defmodule TdQxWeb.Router do
  use TdQxWeb, :router

  pipeline :api do
    plug(TdCore.Auth.Pipeline.Unsecure)
    plug(:accepts, ["json"])
  end

  pipeline :api_auth do
    plug(TdCore.Auth.Pipeline.Secure)
  end

  scope "/api", TdQxWeb do
    pipe_through(:api)

    get("/ping", PingController, :ping)
  end

  scope "/api", TdQxWeb do
    pipe_through([:api, :api_auth])

    resources("/data_views", DataViewController, except: [:new, :edit])
    resources("/quality_functions", FunctionController, except: [:new, :edit])

    scope "/quality_controls" do
      post("/search", SearchController, :create)
      post("/filters", SearchController, :filters)
      get("/reindex", SearchController, :reindex)

      post("/execution_groups/create", ExecutionGroupsController, :create)
      resources "/execution_groups", ExecutionGroupsController, only: [:index, :show]
    end

    resources "/quality_controls", QualityControlController,
      only: [:index, :show, :delete, :create] do
      get("/versions", QualityControlController, :index_versions)
      get("/published", QualityControlController, :show_published)
      post("/draft", QualityControlController, :create_draft)
      patch("/draft", QualityControlController, :update_draft)
      patch("/status", QualityControlController, :update_status)
      patch("/domains", QualityControlController, :update_domain)
    end
  end
end
