defmodule TdQx.DataSets.DataSet do
  @moduledoc """
  Schema for DataSet
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "data_sets" do
    field :name, :string
    field :data_structure_id, :integer
    field :data_structure, :map, virtual: true

    timestamps()
  end

  @doc false
  def changeset(data_set, attrs) do
    data_set
    |> cast(attrs, [:name, :data_structure_id])
    |> validate_required([:name, :data_structure_id])
  end
end
