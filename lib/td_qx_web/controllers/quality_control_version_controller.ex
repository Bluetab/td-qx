defmodule TdQxWeb.QualityControlVersionController do
  use TdQxWeb, :controller

  alias TdQx.QualityControls
  alias TdQx.QualityControls.Actions
  alias TdQx.QualityControls.QualityControlVersion

  action_fallback TdQxWeb.FallbackController

  def index(conn, %{"quality_control_id" => quality_control_id}) do
    quality_control_versions =
      QualityControls.list_quality_control_versions(quality_control_ids: quality_control_id)

    render(conn, :index, quality_control_versions: quality_control_versions)
  end

  def show(conn, %{"quality_control_id" => id, "version" => version}) do
    claims = conn.assigns[:current_resource]

    with %QualityControlVersion{quality_control: quality_control} = quality_control_version <-
           QualityControls.get_quality_control_version(id, version,
             enrich: [:domains, :control_properties],
             preload: [quality_control: {:versions, :desc}]
           ),
         :ok <- Bodyguard.permit(QualityControls, :show, claims, quality_control) do
      conn
      |> Actions.put_actions(claims, quality_control_version)
      |> render(:show, quality_control_version: quality_control_version)
    else
      nil -> {:error, :not_found}
      fallback -> fallback
    end
  end

  def delete(conn, %{"quality_control_id" => id, "version" => version}) do
    claims = conn.assigns[:current_resource]

    with %QualityControlVersion{} = quality_control_version <-
           QualityControls.get_quality_control_version(id, version, preload: [:quality_control]),
         :ok <- Bodyguard.permit(QualityControls, :delete, claims, quality_control_version),
         {:ok, _response} <-
           QualityControls.delete_quality_control_version(quality_control_version) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
      fallback -> fallback
    end
  end
end
