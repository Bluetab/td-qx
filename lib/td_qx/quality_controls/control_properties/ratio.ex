defmodule TdQx.QualityControls.ControlProperties.Ratio do
  @moduledoc """
  Ecto Schema module for QualityControl ControlProperties Ratio
  """

  use Ecto.Schema

  import Ecto.Changeset
  alias TdQx.DataViews.Resource
  alias TdQx.Expressions.Clause

  @primary_key false
  embedded_schema do
    embeds_one(:resource, Resource, on_replace: :delete)
    embeds_many(:validation, Clause, on_replace: :delete)
  end

  def to_json(%__MODULE__{} = ratio) do
    %{
      resource: Resource.to_json(ratio.resource),
      validation: Clause.to_json(ratio.validation)
    }
  end

  def to_json(_), do: nil

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [])
    |> cast_embed(:resource, with: &Resource.changeset/2, required: true)
    |> cast_embed(:validation, with: &Clause.changeset/2, required: true)
  end

  def enrich_resources(%__MODULE__{} = ratio, enrich_fun) do
    %{ratio | resource: enrich_fun.(ratio.resource)}
  end
end
