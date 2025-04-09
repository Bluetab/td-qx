defmodule TdQxWeb.QualityControlJSON do
  alias TdQx.QualityControls.QualityControl
  alias TdQx.QualityControls.QualityControlVersion
  alias TdQxWeb.QualityControlVersionJSON

  @doc """
  Renders a list of quality_controls.
  """
  def index(%{quality_controls: quality_controls, resources_lookup: resources_lookup}) do
    %{
      data: %{
        quality_controls:
          for(quality_control <- quality_controls, do: render_one(quality_control)),
        resources_lookup: resources_lookup
      }
    }
  end

  def index(%{quality_controls: quality_controls}) do
    %{data: for(quality_control <- quality_controls, do: render_one(quality_control))}
  end

  @doc """
  Renders a single quality_control.
  """
  def show(%{quality_control: quality_control, actions: actions}) do
    %{data: render_one(quality_control), _actions: actions}
  end

  def show(%{quality_control: quality_control}) do
    %{data: render_one(quality_control)}
  end

  def render_one(%QualityControlVersion{} = qcv), do: QualityControlVersionJSON.render_one(qcv)

  def render_one(
        %QualityControl{latest_version: %QualityControlVersion{} = quality_control_version} =
          quality_control
      ) do
    quality_control
    |> data()
    |> Map.merge(QualityControlVersionJSON.data(quality_control_version))
  end

  def render_one(
        %QualityControl{published_version: %QualityControlVersion{} = quality_control_version} =
          quality_control
      ) do
    quality_control
    |> data()
    |> Map.merge(QualityControlVersionJSON.data(quality_control_version))
  end

  def render_one(
        %QualityControlVersion{
          quality_control: %QualityControl{} = quality_control
        } = quality_control_version
      ) do
    quality_control
    |> data()
    |> Map.merge(QualityControlVersionJSON.data(quality_control_version))
  end

  def render_one(_), do: nil

  def data(%QualityControl{} = quality_control) do
    versions =
      if Ecto.assoc_loaded?(Map.get(quality_control, :versions)) do
        for(
          version <- Map.get(quality_control, :versions),
          do: QualityControlVersionJSON.data(version)
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
end
