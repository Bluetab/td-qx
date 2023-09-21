defmodule TdQx.DataViews.QueryableProperties.GroupBy do
  @moduledoc """
  Ecto Schema module for DataViews QueryablesProperties GroupBy
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdQx.DataViews.QueryableProperties.SelectField
  alias TdQx.Helpers

  @primary_key false
  embedded_schema do
    embeds_many(:group_fields, SelectField, on_replace: :delete)
    embeds_many(:aggregate_fields, SelectField, on_replace: :delete)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [])
    |> cast_embed(:group_fields, with: &SelectField.changeset/2, required: true)
    |> cast_embed(:aggregate_fields, with: &SelectField.changeset_for_aggregate/2)
    |> validate_unique_field_alias()
  end

  defp validate_unique_field_alias(changeset) do
    changeset
    |> get_field(:group_fields)
    |> Enum.concat(get_field(changeset, :aggregate_fields))
    |> Enum.map(& &1.alias)
    |> Helpers.has_duplicates?()
    |> if do
      add_error(changeset, :fields, "invalid duplicated alias")
    else
      changeset
    end
  end
end
