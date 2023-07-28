defmodule TdQx.Functions.Expressions.Field do
  @moduledoc """
  Ecto Schema module for Function Expression value of shape 'field'
  """

  use Ecto.Schema

  import Ecto.Changeset
  alias TdQx.Functions

  @primary_key false
  embedded_schema do
    field :type, :string
    field :name, :string
    field :dataset, :map
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:type, :name, :dataset])
    |> validate_required([:type, :name, :dataset])
    |> Functions.Function.validate_type()
  end
end
