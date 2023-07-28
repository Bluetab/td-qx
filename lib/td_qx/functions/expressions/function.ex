defmodule TdQx.Functions.Expressions.Function do
  @moduledoc """
  Ecto Schema module for Function Expression value of shape 'function'
  """

  use Ecto.Schema

  import Ecto.Changeset
  alias TdQx.Functions

  @primary_key false
  embedded_schema do
    field :type, :string
    field :name, :string
    field :args, :map
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:type, :name, :args])
    |> validate_required([:type, :name])
    |> Functions.Function.validate_type()
  end
end
