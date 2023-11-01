defmodule TdQxWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use TdQxWeb, :controller

  # This clause handles errors returned by Ecto's insert/update/delete.
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: TdQxWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  # This clause handles errors returned by Ecto's multi.
  def call(conn, {:error, _, %Ecto.Changeset{} = changeset, _}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: TdQxWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  # This clause is an example of how to handle resources that cannot be found.
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: TdQxWeb.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> put_view(json: TdQxWeb.ErrorJSON)
    |> render(:"403")
  end

  def call(conn, {:error, :invalid_action, action}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: "invalid action #{action}"})
  end
end
