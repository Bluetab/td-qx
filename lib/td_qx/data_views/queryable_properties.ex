defmodule TdQx.DataViews.QueryableProperties do
  @moduledoc """
  Ecto Schema module for DataViews Resources
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Ecto.Query.Builder.GroupBy
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

  defp update_resource_refs(resource_refs, {id, resource_ref}) do
    Map.put_new(resource_refs, id, resource_ref)
  end

  def unfold(%{properties: %{from: %From{} = from}} = queryable, resource_refs) do
    {resource_ref, from} = From.unfold(from, queryable)
    {update_resource_refs(resource_refs, resource_ref), from}
  end

  def unfold(%{properties: %{join: %Join{} = join}} = queryable, resource_refs) do
    {resource_ref, join} = Join.unfold(join, queryable)
    {update_resource_refs(resource_refs, resource_ref), join}
  end

  def unfold(%{properties: %{where: %Where{} = where}}, resource_refs) do
    {resource_refs, Where.unfold(where)}
  end

  def unfold(%{properties: %{select: %Select{} = select}} = queryable, resource_refs) do
    {resource_ref, select} = Select.unfold(select, queryable)
    {update_resource_refs(resource_refs, resource_ref), select}
  end

  def unfold(%{properties: %{group_by: %GroupBy{} = group_by}} = queryable, resource_refs) do
    {resource_ref, group_by} = GroupBy.unfold(group_by, queryable)
    {update_resource_refs(resource_refs, resource_ref), group_by}
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
