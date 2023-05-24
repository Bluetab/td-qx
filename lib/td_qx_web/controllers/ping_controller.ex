defmodule TdQxWeb.PingController do
  use TdQxWeb, :controller

  def ping(conn, _params) do
    send_resp(conn, :ok, "pong")
  end
end
