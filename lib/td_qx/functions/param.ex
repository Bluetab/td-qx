defmodule TdQx.Functions.Param do
  @moduledoc """
  Ecto Schema module for Function Params
  """

  use Ecto.Schema

  import Ecto.Changeset
  alias TdQx.Functions.Function

  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:type, :string)
    field(:description, :string)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:name, :type, :description])
    |> validate_required([:name, :type])
    |> Function.validate_type()
  end
end
