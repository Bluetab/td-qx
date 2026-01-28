defmodule TdQx.QualityControls.ControlProperties.Ratio do
  @moduledoc """
  Ecto Schema module for QualityControl ControlProperties Ratio
  """

  use Ecto.Schema

  import Ecto.Changeset
  alias TdQx.DataViews.Queryable
  alias TdQx.DataViews.Resource
  alias TdQx.Expressions.Clause

  @primary_key false
  @derive Jason.Encoder
  embedded_schema do
    embeds_one(:resource, Resource, on_replace: :delete)
    embeds_many(:validation, Clause, on_replace: :delete)
    embeds_one(:segmentation, Queryable, on_replace: :delete)
  end

  def to_json(%__MODULE__{} = ratio) do
    %{
      resource: Resource.to_json(ratio.resource),
      validation: Clause.to_json(ratio.validation),
      segmentation: Queryable.to_json(ratio.segmentation)
    }
  end

  def to_json(_), do: nil

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [])
    |> cast_embed(:resource, with: &Resource.changeset/2, required: true)
    |> cast_embed(:validation, with: &Clause.changeset/2, required: true)
    |> cast_embed(:segmentation, with: &segmentation_changeset/2)
  end

  defp segmentation_changeset(%Queryable{} = struct, %{} = params) do
    struct
    |> Queryable.changeset(params)
    |> validate_change(:type, fn _, type ->
      if type == "group_by" do
        []
      else
        [{:type, "segmentation queryable must be of type 'group_by'"}]
      end
    end)
  end

  defp segmentation_changeset(_struct, params) do
    segmentation_changeset(%Queryable{}, params)
  end

  def enrich_resources(%__MODULE__{} = ratio, enrich_fun) do
    %{ratio | resource: enrich_fun.(ratio.resource)}
  end
end
