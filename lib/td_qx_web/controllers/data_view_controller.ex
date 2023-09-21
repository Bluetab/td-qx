defmodule TdQxWeb.DataViewController do
  use TdQxWeb, :controller

  alias TdQx.DataViews
  alias TdQx.DataViews.DataView

  action_fallback TdQxWeb.FallbackController

  def index(conn, _params) do
    with claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(DataViews, :view, claims),
         data_views <- DataViews.list_data_views(enrich: true) do
      render(conn, :index, data_views: data_views)
    end
  end

  def create(conn, %{"data_view" => data_view_params}) do
    with %{user_id: user_id} = claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(DataViews, :create, claims),
         params <- Map.put(data_view_params, "created_by_id", user_id),
         {:ok, %DataView{} = data_view} <-
           DataViews.create_data_view(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/data_views/#{data_view}")
      |> render(:show, data_view: data_view)
    end
  end

  def show(conn, %{"id" => id}) do
    with claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(DataViews, :view, claims),
         data_view <- DataViews.get_data_view!(id, enrich: true) do
      render(conn, :show, data_view: data_view)
    end
  end

  def update(conn, %{"id" => id, "data_view" => data_view_params}) do
    data_view = DataViews.get_data_view!(id)

    with claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(DataViews, :update, claims),
         {:ok, %DataView{} = data_view} <-
           DataViews.update_data_view(data_view, data_view_params) do
      render(conn, :show, data_view: data_view)
    end
  end

  def delete(conn, %{"id" => id}) do
    data_view = DataViews.get_data_view!(id)

    with claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(DataViews, :delete, claims),
         {:ok, %DataView{}} <- DataViews.delete_data_view(data_view) do
      send_resp(conn, :no_content, "")
    end
  end
end
