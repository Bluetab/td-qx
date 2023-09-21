defmodule TdQx.DataViews.QueryableProperties.SelectField do
  @moduledoc """
  Ecto Schema module for DataViews QueryablesProperties SelectField
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdQx.Expressions.Expression

  @primary_key false
  embedded_schema do
    field(:id, :integer)
    field(:alias, :string)
    embeds_one(:expression, Expression, on_replace: :delete)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:alias, :id])
    |> cast_embed(:expression, with: &Expression.changeset/2, required: true)
    |> validate_required([:alias, :id])
  end

  def changeset_for_aggregate(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:alias, :id])
    |> cast_embed(:expression, with: &Expression.changeset_for_aggregate/2, required: true)
    |> validate_required([:alias, :id])
  end
end
