defmodule TdQx.DataViews.QueryableProperties do
  @moduledoc """
  Ecto Schema module for DataViews Resources
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdQx.DataViews.QueryableProperties.From
  alias TdQx.DataViews.QueryableProperties.GroupBy
  alias TdQx.DataViews.QueryableProperties.Join
  alias TdQx.DataViews.QueryableProperties.Select
  alias TdQx.DataViews.QueryableProperties.Where

  @primary_key false
  embedded_schema do
    embeds_one(:join, Join, on_replace: :delete)
    embeds_one(:group_by, GroupBy, on_replace: :delete)
    embeds_one(:from, From, on_replace: :delete)
    embeds_one(:select, Select, on_replace: :delete)
    embeds_one(:where, Where, on_replace: :delete)
  end

  def changeset(%__MODULE__{} = struct, %{} = params, type) do
    prop_params = %{type => params}

    struct
    |> cast(prop_params, [])
    |> cast_properties_embed(type)
  end

  defp cast_properties_embed(changeset, "join"),
    do: cast_embed(changeset, :join, with: &Join.changeset/2)

  defp cast_properties_embed(changeset, "group_by"),
    do: cast_embed(changeset, :group_by, with: &GroupBy.changeset/2)

  defp cast_properties_embed(changeset, "from"),
    do: cast_embed(changeset, :from, with: &From.changeset/2)

  defp cast_properties_embed(changeset, "where"),
    do: cast_embed(changeset, :where, with: &Where.changeset/2)

  defp cast_properties_embed(changeset, "select"),
    do: cast_embed(changeset, :select, with: &Select.changeset/2)

  defp cast_properties_embed(changeset, _),
    do: add_error(changeset, :properties_type, "invalid")
end
