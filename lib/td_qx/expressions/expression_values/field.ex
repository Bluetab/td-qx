defmodule TdQx.Expressions.ExpressionValues.Field do
  @moduledoc """
  Ecto Schema module for ExpressionValue of shape field
  """

  use Ecto.Schema

  alias TdQx.Functions.Function

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :id, :integer
    field :type, :string
    field :name, :string
    field :parent_id, :integer
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:id, :type, :name, :parent_id])
    |> validate_required([:id, :type, :name, :parent_id])
    |> Function.validate_type()
  end

  def to_json(%__MODULE__{} = field) do
    %{
      id: field.id,
      type: field.type,
      name: field.name,
      parent_id: field.parent_id
    }
  end

  def to_json(_), do: nil
end
