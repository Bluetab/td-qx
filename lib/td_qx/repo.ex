defmodule TdQx.Repo do
  use Ecto.Repo,
    otp_app: :td_qx,
    adapter: Ecto.Adapters.Postgres
end
