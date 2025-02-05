defmodule TdQx.QualityControls.ControlProperties.ErrorCount do
  @moduledoc """
  Ecto Schema module for QualityControl ControlProperties ErrorCount
  """

  use Ecto.Schema

  import Ecto.Changeset
  alias TdQx.DataViews.Resource

  @primary_key false
  embedded_schema do
    embeds_one(:errors_resource, Resource, on_replace: :delete)
  end

  def to_json(%__MODULE__{} = error_count) do
    %{
      errors_resource: Resource.to_json(error_count.errors_resource)
    }
  end

  def to_json(_), do: nil

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [])
    |> cast_embed(:errors_resource, with: &Resource.changeset/2, required: true)
  end

  def enrich_resources(%__MODULE__{} = error_count, enrich_fun) do
    %{error_count | errors_resource: enrich_fun.(error_count.errors_resource)}
  end
end
