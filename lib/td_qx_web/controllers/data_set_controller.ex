defmodule TdQxWeb.DataSetController do
  use TdQxWeb, :controller

  alias TdQx.DataSets
  alias TdQx.DataSets.DataSet

  action_fallback TdQxWeb.FallbackController

  def index(conn, _params) do
    with claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(DataSets, :view, claims),
         data_sets <- DataSets.list_data_sets(enrich: true) do
      render(conn, :index, data_sets: data_sets)
    end
  end

  def create(conn, %{"data_set" => data_set_params}) do
    with claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(DataSets, :create, claims),
         {:ok, %DataSet{} = data_set} <-
           DataSets.create_data_set(data_set_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/data_sets/#{data_set}")
      |> render(:show, data_set: data_set)
    end
  end

  def show(conn, %{"id" => id}) do
    with claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(DataSets, :view, claims),
         data_set <- DataSets.get_data_set!(id, enrich: true) do
      render(conn, :show, data_set: data_set)
    end
  end

  def update(conn, %{"id" => id, "data_set" => data_set_params}) do
    data_set = DataSets.get_data_set!(id)

    with claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(DataSets, :update, claims),
         {:ok, %DataSet{} = data_set} <-
           DataSets.update_data_set(data_set, data_set_params) do
      render(conn, :show, data_set: data_set)
    end
  end

  def delete(conn, %{"id" => id}) do
    data_set = DataSets.get_data_set!(id)

    with claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(DataSets, :delete, claims),
         {:ok, %DataSet{}} <- DataSets.delete_data_set(data_set) do
      send_resp(conn, :no_content, "")
    end
  end
end
