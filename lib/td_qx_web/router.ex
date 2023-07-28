defmodule TdQxWeb.Router do
  use TdQxWeb, :router

  pipeline :api do
    plug TdQx.Auth.Pipeline.Unsecure
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug TdQx.Auth.Pipeline.Secure
  end

  scope "/api", TdQxWeb do
    pipe_through :api

    get "/ping", PingController, :ping
  end

  scope "/api", TdQxWeb do
    pipe_through [:api, :api_auth]

    resources "/data_sets", DataSetController, except: [:new, :edit]
    resources "/functions", FunctionController, except: [:new, :edit]
  end
end
