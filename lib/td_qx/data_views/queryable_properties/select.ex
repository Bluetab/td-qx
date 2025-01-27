defmodule TdQx.DataViews.QueryableProperties.Select do
  @moduledoc """
  Ecto Schema module for DataViews QueryablesProperties Select
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdQx.DataViews.Queryable
  alias TdQx.DataViews.QueryableProperties.SelectField
  alias TdQx.Helpers

  @primary_key false
  embedded_schema do
    embeds_many(:fields, SelectField, on_replace: :delete)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [])
    |> cast_embed(:fields, with: &SelectField.changeset/2, required: true)
    |> validate_unique_field_alias()
  end

  defp validate_unique_field_alias(changeset) do
    changeset
    |> get_field(:fields)
    |> Enum.map(& &1.alias)
    |> Helpers.has_duplicates?()
    |> if do
      add_error(changeset, :fields, "invalid duplicated alias")
    else
      changeset
    end
  end

  def to_json(%__MODULE__{fields: fields}) do
    %{fields: SelectField.to_json(fields)}
  end

  def to_json(_), do: nil

  def unfold(
        %__MODULE__{fields: fields},
        %Queryable{id: id, alias: queryable_alias}
      ) do
    resource_ref = %{
      type: "select",
      id: nil,
      alias: queryable_alias
    }

    {{id, resource_ref},
     %{__type__: "select", fields: SelectField.unfold(fields), resource_ref: id}}
  end
end
