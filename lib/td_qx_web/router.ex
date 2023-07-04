defmodule TdQxWeb.Router do
  use TdQxWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", TdQxWeb do
    pipe_through :api

    get "/ping", PingController, :ping
  end

  scope "/api", TdQxWeb do
    pipe_through :api

    resources "/data_sets", DataSetController, except: [:new, :edit]
  end
end
