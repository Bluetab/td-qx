defmodule TdQx.DataViews.DataView do
  @moduledoc """
  Schema for DataView
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias TdQx.DataViews.Queryable
  alias TdQx.Helpers

  @mode ~w(guided advanced)a

  schema "data_views" do
    field(:name, :string)
    field(:created_by_id, :integer)
    field(:source_id, :integer)
    field(:description, :string)
    field(:mode, Ecto.Enum, values: @mode, default: :advanced)

    embeds_many(:queryables, Queryable, on_replace: :delete)

    embeds_one(:select, Queryable, on_replace: :delete)

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(data_view, attrs) do
    data_view
    |> cast(attrs, [:name, :created_by_id, :description, :source_id, :mode])
    |> cast_embed(:queryables, with: &Queryable.changeset/2, required: true)
    |> cast_embed(:select, with: &Queryable.changeset_for_select/2, required: true)
    |> validate_required([:name, :created_by_id, :source_id, :mode])
    |> validate_unique_queryable_alias
    |> validate_unique_queryable_resources
  end

  def unfold(%__MODULE__{queryables: queryables, select: select}) do
    {resource_refs, queryables} = Queryable.unfold(queryables)
    select = unfold_select(select)
    %{__type__: "data_view", queryables: queryables, select: select, resource_refs: resource_refs}
  end

  defp unfold_select(nil), do: nil

  defp unfold_select(select) do
    {_, [select]} = Queryable.unfold(select)
    select
  end

  defp validate_unique_queryable_alias(changeset) do
    changeset
    |> get_field(:queryables)
    |> Enum.map(& &1.alias)
    |> Enum.reject(&is_nil/1)
    |> Helpers.has_duplicates?()
    |> if do
      add_error(changeset, :queryables, "invalid duplicated alias")
    else
      changeset
    end
  end

  defp validate_unique_queryable_resources(changeset) do
    changeset
    |> get_field(:queryables)
    |> Enum.map(&queryable_resource/1)
    |> Enum.reject(&is_nil/1)
    |> Helpers.has_duplicates?()
    |> if do
      add_error(changeset, :queryables, "invalid duplicated resources")
    else
      changeset
    end
  end

  defp queryable_resource(%{
         type: "join",
         alias: queryable_alias,
         properties: %{join: %{resource: %{id: id, type: type}}}
       }),
       do: {id, type, queryable_alias}

  defp queryable_resource(%{
         type: "from",
         alias: queryable_alias,
         properties: %{from: %{resource: %{id: id, type: type}}}
       }),
       do: {id, type, queryable_alias}

  defp queryable_resource(_), do: nil
end
