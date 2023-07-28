defmodule TdQxWeb.FunctionController do
  use TdQxWeb, :controller

  alias TdQx.Functions
  alias TdQx.Functions.Function

  action_fallback TdQxWeb.FallbackController

  def index(conn, _params) do
    with claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(Functions, :view, claims),
         functions <- Functions.list_functions() do
      render(conn, :index, functions: functions)
    end
  end

  def create(conn, %{"function" => function_params}) do
    with claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(Functions, :create, claims),
         {:ok, %Function{} = function} <- Functions.create_function(function_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/functions/#{function}")
      |> render(:show, function: function)
    end
  end

  def show(conn, %{"id" => id}) do
    with claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(Functions, :view, claims),
         function <- Functions.get_function!(id) do
      render(conn, :show, function: function)
    end
  end

  def update(conn, %{"id" => id, "function" => function_params}) do
    function = Functions.get_function!(id)

    with claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(Functions, :update, claims),
         {:ok, %Function{} = function} <- Functions.update_function(function, function_params) do
      render(conn, :show, function: function)
    end
  end

  def delete(conn, %{"id" => id}) do
    function = Functions.get_function!(id)

    with claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(Functions, :delete, claims),
         {:ok, %Function{}} <- Functions.delete_function(function) do
      send_resp(conn, :no_content, "")
    end
  end
end
