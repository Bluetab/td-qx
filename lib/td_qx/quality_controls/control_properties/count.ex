defmodule TdQx.QualityControls.ControlProperties.Count do
  @moduledoc """
  Ecto Schema module for QualityControl ControlProperties Count
  """

  use Ecto.Schema

  import Ecto.Changeset
  alias TdQx.DataViews.Resource

  @primary_key false
  @derive Jason.Encoder
  embedded_schema do
    embeds_one(:errors_resource, Resource, on_replace: :delete)
  end

  def to_json(%__MODULE__{} = count) do
    %{
      errors_resource: Resource.to_json(count.errors_resource)
    }
  end

  def to_json(_), do: nil

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [])
    |> cast_embed(:errors_resource, with: &Resource.changeset/2, required: true)
  end

  def enrich_resources(%__MODULE__{} = count, enrich_fun) do
    %{count | errors_resource: enrich_fun.(count.errors_resource)}
  end
end
