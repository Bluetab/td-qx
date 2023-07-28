defmodule TdQx.Functions.Expression do
  @moduledoc """
  Ecto Schema module for Function Expression
  """

  use Ecto.Schema

  import Ecto.Changeset
  # import PolymorphicEmbed
  # alias TdQx.Functions.Expressions

  @primary_key false
  embedded_schema do
    field :shape, :string
    field :value, :map

    # polymorphic_embeds_one(:value,
    #   types: [
    #     constant: TdQx.Functions.Expressions.Constant,
    #     function: TdQx.Functions.Expressions.Function,
    #     param: TdQx.Functions.Expressions.Param,
    #     field: TdQx.Functions.Expressions.Field
    #   ],
    #   on_type_not_found: :raise,
    #   on_replace: :update
    # )
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:shape, :value])
    # |> dbg
    # |> cast_polymorphic_embed(:value, required: true)
    |> validate_required([:shape, :value])
    # |> cast_value()
    |> validate_inclusion(:shape, ~w|constant function param field|)
  end

  # defp cast_value(changeset), do: cast_embed(changeset, :value, shape_changeset(changeset))

  # defp shape_changeset(_changeset) do
  #   &Expressions.Constant.changeset/2
  # end
end
