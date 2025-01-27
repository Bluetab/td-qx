defmodule TdQxWeb.QualityControlJSON do
  alias TdQx.QualityControls.ControlProperties
  alias TdQx.QualityControls.QualityControl
  alias TdQx.QualityControls.QualityControlVersion
  alias TdQx.QualityControls.ScoreCriteria

  @doc """
  Renders a list of quality_controls.
  """
  def index(%{quality_controls: quality_controls, resources_lookup: resources_lookup}) do
    %{
      data: %{
        quality_controls: for(quality_control <- quality_controls, do: data(quality_control)),
        resources_lookup: resources_lookup
      }
    }
  end

  def index(%{quality_controls: quality_controls}) do
    %{data: for(quality_control <- quality_controls, do: data(quality_control))}
  end

  @doc """
  Renders a single quality_control.
  """
  def show(%{quality_control: quality_control, actions: actions}) do
    %{data: data(quality_control), _actions: actions}
  end

  def show(%{quality_control: quality_control}) do
    %{data: data(quality_control)}
  end

  def render_one(%QualityControlVersion{} = qcv), do: data(qcv)
  def render_one(_), do: nil

  defp data(
         %QualityControl{
           latest_version: %QualityControlVersion{} = quality_control_version
         } = quality_control
       ) do
    quality_control
    |> quality_control_data()
    |> Map.merge(quality_control_version_data(quality_control_version))
  end

  defp data(
         %QualityControl{
           published_version: %QualityControlVersion{} = quality_control_version
         } = quality_control
       ) do
    quality_control
    |> quality_control_data()
    |> Map.merge(quality_control_version_data(quality_control_version))
  end

  defp data(
         %QualityControlVersion{
           quality_control: %QualityControl{} = quality_control
         } = quality_control_version
       ) do
    quality_control
    |> quality_control_data()
    |> Map.merge(quality_control_version_data(quality_control_version))
  end

  defp quality_control_data(%QualityControl{} = quality_control) do
    versions =
      if Ecto.assoc_loaded?(Map.get(quality_control, :versions)) do
        for(
          version <- Map.get(quality_control, :versions),
          do: quality_control_version_data(version)
        )
      else
        nil
      end

    %{
      id: quality_control.id,
      domain_ids: quality_control.domain_ids,
      domains: quality_control.domains,
      source_id: quality_control.source_id,
      active: quality_control.active,
      versions: versions
    }
  end

  defp quality_control_version_data(%QualityControlVersion{} = quality_control_version) do
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
      queries: quality_control_version.queries
    }
  end
end
