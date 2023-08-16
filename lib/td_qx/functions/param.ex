defmodule TdQx.Functions.Param do
  @moduledoc """
  Ecto Schema module for Function Params
  """

  use Ecto.Schema

  import Ecto.Changeset
  alias TdQx.Functions.Function

  @primary_key false
  embedded_schema do
    field(:id, :integer)
    field(:name, :string)
    field(:type, :string)
    field(:description, :string)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:id, :name, :type, :description])
    |> validate_required([:id, :name, :type])
    |> Function.validate_type()
  end
end
