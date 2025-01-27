defmodule TdQxWeb.QualityControlController do
  use TdQxWeb, :controller

  alias TdQx.QualityControls
  alias TdQx.QualityControls.Actions
  alias TdQx.QualityControls.QualityControl
  alias TdQx.QualityControls.QualityControlVersion
  alias TdQx.QualityControlTransformer
  alias TdQx.QualityControlWorkflow

  action_fallback TdQxWeb.FallbackController

  def index_versions(conn, %{"quality_control_id" => quality_control_id}) do
    quality_controls = QualityControls.list_quality_control_versions(quality_control_id)
    render(conn, :index, quality_controls: quality_controls)
  end

  def show(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]

    quality_control =
      QualityControls.get_quality_control!(id,
        enrich: [:domains, :control_properties],
        preload: [:versions, :published_version]
      )

    with :ok <- Bodyguard.permit(QualityControls, :show, claims, quality_control) do
      conn
      |> Actions.put_actions(claims, quality_control)
      |> render(:show, quality_control: quality_control)
    end
  end

  def create(conn, %{"quality_control" => quality_control_params}) do
    claims = conn.assigns[:current_resource]

    status = Map.get(quality_control_params, "status")
    domain_ids = QualityControl.domain_id_from_params(quality_control_params)

    with :ok <- Bodyguard.permit(QualityControls, :create, claims, {domain_ids, status}),
         {:ok,
          %QualityControlVersion{quality_control_id: quality_control_id} = quality_control_version} <-
           QualityControlWorkflow.create_quality_control(quality_control_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/quality_controls/#{quality_control_id}")
      |> render(:show, quality_control: quality_control_version)
    end
  end

  def create_draft(
        conn,
        %{
          "quality_control_id" => quality_control_id,
          "quality_control" => quality_control_params
        }
      ) do
    claims = conn.assigns[:current_resource]

    quality_control =
      QualityControls.get_quality_control!(quality_control_id, preload: :published_version)

    status = Map.get(quality_control_params, "status")

    with :ok <-
           Bodyguard.permit(QualityControls, :create_draft, claims, {quality_control, status}),
         {:ok, quality_control_version} <-
           QualityControlWorkflow.create_quality_control_draft(
             quality_control,
             quality_control_params
           ) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/quality_controls/#{quality_control_id}")
      |> render(:show, quality_control: quality_control_version)
    end
  end

  def update_draft(
        conn,
        %{
          "quality_control_id" => quality_control_id,
          "quality_control" => quality_control_params
        }
      ) do
    claims = conn.assigns[:current_resource]

    %{latest_version: quality_control_version} =
      quality_control = QualityControls.get_quality_control!(quality_control_id)

    with :ok <- Bodyguard.permit(QualityControls, :update_draft, claims, quality_control),
         {:ok, quality_control_version} <-
           QualityControlWorkflow.update_quality_control_draft(
             quality_control_version,
             quality_control_params
           ) do
      render(conn, :show, quality_control: quality_control_version)
    end
  end

  def update_main(
        conn,
        %{
          "quality_control_id" => quality_control_id,
          "quality_control" => quality_control_params
        }
      ) do
    claims = conn.assigns[:current_resource]

    quality_control = QualityControls.get_quality_control!(quality_control_id)

    with :ok <- Bodyguard.permit(QualityControls, :update_main, claims, quality_control),
         {:ok, _} <-
           QualityControls.update_quality_control(
             quality_control,
             quality_control_params
           ) do
      render(conn, :show,
        quality_control: QualityControls.get_quality_control!(quality_control_id)
      )
    end
  end

  def update_status(conn, %{
        "quality_control_id" => quality_control_id,
        "action" => action
      }) do
    claims = conn.assigns[:current_resource]

    quality_control =
      QualityControls.get_quality_control!(quality_control_id, preload: :published_version)

    with :ok <- Bodyguard.permit(QualityControls, action, claims, quality_control),
         {:ok, quality_control_version} <-
           QualityControlWorkflow.update_quality_control_status(quality_control, action) do
      render(conn, :show, quality_control: quality_control_version)
    end
  end

  def delete(conn, %{"id" => id}) do
    quality_control = QualityControls.get_quality_control!(id)

    with {:ok, %QualityControl{}} <- QualityControls.delete_quality_control(quality_control) do
      send_resp(conn, :no_content, "")
    end
  end

  def queries(conn, %{"quality_control_id" => id}) do
    claims = conn.assigns[:current_resource]
    %{latest_version: latest_version} = quality_control = QualityControls.get_quality_control!(id)

    with :ok <- Bodyguard.permit(QualityControls, :show, claims, quality_control) do
      queries = QualityControlTransformer.queries_from(latest_version)
      resources_lookup = QualityControlTransformer.build_resources_lookup(queries)

      json(conn, %{
        data: %{
          queries: queries,
          resources_lookup: resources_lookup
        }
      })
    end
  end

  def queries_by_source_id(conn, %{"source_id" => source_id}) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(QualityControls, :search, claims) do
      quality_controls =
        source_id
        |> QualityControls.list_published_versions_by_source_id()
        |> QualityControlTransformer.enrich_quality_controls_queries()

      queries = Enum.flat_map(quality_controls, & &1.queries)
      resources_lookup = QualityControlTransformer.build_resources_lookup(queries)

      render(conn, :index,
        quality_controls: quality_controls,
        resources_lookup: resources_lookup
      )
    end
  end
end
