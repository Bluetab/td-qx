defmodule TdQxWeb.Router do
  use TdQxWeb, :router

  pipeline :api do
    plug TdCore.Auth.Pipeline.Unsecure
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug TdCore.Auth.Pipeline.Secure
  end

  scope "/api", TdQxWeb do
    pipe_through :api

    get "/ping", PingController, :ping
  end

  scope "/api", TdQxWeb do
    pipe_through [:api, :api_auth]

    resources "/data_views", DataViewController, except: [:new, :edit]
    resources "/quality_functions", FunctionController, except: [:new, :edit]

    scope "/quality_controls" do
      post "/search", SearchController, :create
      post "/filters", SearchController, :filters
      get "/reindex", SearchController, :quality_controls_reindex
      get "/queries/:source_id", QualityControlController, :queries_by_source_id
    end

    resources "/quality_controls", QualityControlController, only: [:show, :delete, :create] do
      get "/queries", QualityControlController, :queries
      get "/published", QualityControlController, :show_published
      post "/draft", QualityControlController, :create_draft
      patch "/draft", QualityControlController, :update_draft
      patch "/status", QualityControlController, :update_status
      patch "/main", QualityControlController, :update_main
      post("/scores", ScoreController, :search_with_pagination)

      resources "/versions", QualityControlVersionController,
        only: [:show, :index, :delete],
        param: "version"
    end

    scope "/score_groups" do
      post "/filters", SearchController, :score_group_filters
      post "/search", SearchController, :create_score_groups
      get "/reindex", SearchController, :score_groups_reindex
    end

    resources "/score_groups", ScoreGroupController, only: [:index, :create, :show]
    post "/scores/fetch_pending", ScoreController, :fetch_pending
    get "/scores/:id", ScoreController, :show
    post "/scores/:score_id/success", ScoreController, :success
    post "/scores/:score_id/fail", ScoreController, :fail
    delete "/scores/:id", ScoreController, :delete
    post "/scores/:score_id/events", ScoreEventController, :create
  end
end
