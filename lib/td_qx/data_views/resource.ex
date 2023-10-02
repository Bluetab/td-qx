defmodule TdQx.DataViews.Resource do
  @moduledoc """
  Ecto Schema module for DataViews Resources
  """

  use Ecto.Schema

  import Ecto.Changeset

  @valid_types ~w|data_structure reference_dataset data_view|

  @primary_key false
  embedded_schema do
    field(:id, :integer)
    field(:type, :string)
    field(:embedded, :map, virtual: true)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:id, :type])
    |> validate_required([:id, :type])
    |> validate_inclusion(:type, @valid_types)
  end
end
