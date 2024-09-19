defmodule TdQx.QualityControls.QualityControl do
  @moduledoc """
  Ecto Schema module for QualityControl
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias TdQx.QualityControls.QualityControlVersion

  schema "quality_controls" do
    field(:domain_ids, {:array, :integer})
    field(:domains, {:array, :map}, virtual: true)
    field(:source_id, :integer)
    field(:latest_version, :map, virtual: true)

    has_many(:versions, QualityControlVersion)
    has_one(:published_version, QualityControlVersion, where: [status: "published"])

    timestamps()
  end

  @doc false
  def changeset(quality_control, attrs) do
    quality_control
    |> cast(attrs, [:domain_ids, :source_id])
    |> validate_required([:domain_ids, :source_id])
  end

  @doc false
  def domain_id_from_params(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:domain_ids])
    |> fetch_field!(:domain_ids)
  end
end
