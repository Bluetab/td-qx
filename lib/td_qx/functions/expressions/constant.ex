defmodule TdQx.Functions.Expressions.Constant do
  @moduledoc """
  Ecto Schema module for Function Expression value of shape 'constant'
  """

  use Ecto.Schema

  import Ecto.Changeset
  alias TdQx.Functions.Function

  @primary_key false
  embedded_schema do
    field :type, :string
    field :value, :string
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:type, :value])
    |> validate_required([:type, :value])
    |> Function.validate_type()
  end
end
