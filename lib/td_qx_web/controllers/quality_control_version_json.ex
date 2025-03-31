defmodule TdQxWeb.QualityControlVersionJSON do
  alias TdQx.QualityControls.ControlProperties
  alias TdQx.QualityControls.QualityControl
  alias TdQx.QualityControls.QualityControlVersion
  alias TdQx.QualityControls.ScoreCriteria
  alias TdQxWeb.QualityControlJSON

  @doc """
  Renders a list of quality_controls.
  """
  def index(%{quality_control_versions: quality_control_versions}) do
    %{
      data:
        for(
          quality_control_version <- quality_control_versions,
          do: render_one(quality_control_version)
        )
    }
  end

  @doc """
  Renders a single quality_control version.
  """
  def show(%{quality_control_version: quality_control_version, actions: actions}) do
    %{data: render_one(quality_control_version), _actions: actions}
  end

  def show(%{quality_control_version: quality_control_version}) do
    %{data: render_one(quality_control_version)}
  end

  def render_one(
        %QualityControlVersion{quality_control: %QualityControl{} = quality_control} =
          quality_control_version
      ) do
    quality_control
    |> QualityControlJSON.data()
    |> Map.merge(data(quality_control_version))
    |> Map.delete(:quality_control_id)
  end

  def data(%QualityControlVersion{} = quality_control_version) do
    %{
      version_id: quality_control_version.id,
      name: quality_control_version.name,
      status: quality_control_version.status,
      version: quality_control_version.version,
      dynamic_content: quality_control_version.dynamic_content,
      df_type: quality_control_version.df_type,
      control_mode: quality_control_version.control_mode,
      score_criteria: ScoreCriteria.to_json(quality_control_version.score_criteria),
      control_properties: ControlProperties.to_json(quality_control_version.control_properties),
      updated_at: quality_control_version.updated_at,
      queries: quality_control_version.queries,
      quality_control_id: quality_control_version.quality_control_id
    }
  end
end
