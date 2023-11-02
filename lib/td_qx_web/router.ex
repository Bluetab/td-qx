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

    post("/quality_controls/search", SearchController, :create)
    post("/quality_controls/filters", SearchController, :filters)
    get("/quality_controls/reindex", SearchController, :reindex)

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
