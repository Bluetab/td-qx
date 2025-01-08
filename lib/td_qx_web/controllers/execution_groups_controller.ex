defmodule TdQxWeb.ExecutionGroupsController do
  use TdQxWeb, :controller

  alias TdCore.Search
  alias TdCore.Search.Permissions, as: SearchPermissions
  alias TdCore.Search.Query
  alias TdQx.Executions
  alias TdQx.Executions.ExecutionGroup
  alias TdQx.Permissions
  alias TdQx.QualityControls

  action_fallback TdQxWeb.FallbackController
  @default_page 0
  @default_size 999

  def index(conn, _params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Executions, :index, claims) do
      execution_groups = Executions.list_execution_groups()
      render(conn, :index, execution_groups: execution_groups)
    end
  end

  def create(conn, params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Executions, :create, claims),
         quality_controls <- do_search(params, claims),
         {:ok, %{id: id}} <-
           Executions.create_execution_group(quality_controls, params) do
      execution_group = Executions.get_execution_group(id)

      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/quality_controls/execution_groups/#{id}")
      |> render("show.json", execution_group: execution_group)
    end
  end

  def show(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Executions, :show, claims) do
      execution_group = Executions.get_execution_group(id)
      render(conn, :show, execution_group: execution_group)
    end
  end

  def update(conn, %{"id" => id, "execution_groups" => execution_groups_params}) do
    execution_groups = Executions.get_execution_group(id)
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Executions, :update, claims),
         {:ok, %ExecutionGroup{} = execution_groups} <-
           Executions.update_execution_groups(execution_groups, execution_groups_params) do
      render(conn, :show, execution_groups: execution_groups)
    end
  end

  defp do_search(%{"must" => must = %{"executable" => ["true"]}} = params, claims) do
    params
    |> Map.put("must", Map.delete(must, "executable"))
    |> do_search(claims)
    |> Enum.filter(&Permissions.visible_by_permissions?(&1, claims))
  end

  defp do_search(%{} = attr, claims) do
    page = Map.get(attr, "page", @default_page)
    size = Map.get(attr, "size", @default_size)
    sort = Map.get(attr, "sort") || %{}

    {query, _} = build_query(attr, claims)

    search = %{from: page * size, size: size, query: query, sort: sort}

    {:ok, %{total: _total, results: results}} = Search.search(search, :quality_controls)

    results
  end

  defp build_query(params, claims) do
    permissions_filter =
      SearchPermissions.filter_for_permissions(["view_quality_controls"], claims)

    aggs = Search.ElasticDocumentProtocol.aggregations(%QualityControls.QualityControl{})
    query = Query.build_query(permissions_filter, params, aggs)
    {query, aggs}
  end
end
