defmodule TdQxWeb.QualityControlJSON do
  alias TdQx.QualityControls.QualityControl
  alias TdQx.QualityControls.QualityControlVersion

  alias TdDfLib.Content
  alias TdQxWeb.ClauseJSON
  alias TdQxWeb.ResourceJSON
  alias TdQxWeb.ResultCriteriaJSON

  @doc """
  Renders a list of quality_controls.
  """
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
      versions: versions
    }
  end

  defp quality_control_version_data(%QualityControlVersion{} = quality_control_version) do
    %{
      name: quality_control_version.name,
      status: quality_control_version.status,
      version: quality_control_version.version,
      df_content: quality_control_version.df_content,
      df_type: quality_control_version.df_type,
      result_type: quality_control_version.result_type,
      result_criteria: ResultCriteriaJSON.embed_one(quality_control_version),
      resource: ResourceJSON.embed_one(quality_control_version),
      validation: ClauseJSON.embed_many(quality_control_version.validation),
      updated_at: quality_control_version.updated_at
    }
    |> Content.legacy_content_support(:df_content)
  end
end
