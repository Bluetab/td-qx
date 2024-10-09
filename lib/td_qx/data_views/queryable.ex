defmodule TdQx.DataViews.Queryable do
  @moduledoc """
  Ecto Schema module for DataViews Queryables
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdQx.DataViews.QueryableProperties

  @valid_types ~w|from join select where group_by|

  @primary_key false
  embedded_schema do
    field(:id, :integer)
    field(:type, :string)
    field(:alias, :string)

    embeds_one(:properties, QueryableProperties, on_replace: :delete)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    changeset = cast(struct, params, [:id, :type, :alias])

    type = get_field(changeset, :type)

    changeset
    |> cast_embed(:properties, with: &QueryableProperties.changeset(&1, &2, type), required: true)
    |> validate_required([:id, :type])
    |> validate_inclusion(:type, @valid_types)
  end

  def changeset_for_select(%__MODULE__{} = struct, %{} = params) do
    changeset = cast(struct, params, [:type])

    case get_field(changeset, :type) do
      "select" ->
        changeset
        |> cast_embed(:properties,
          with: &QueryableProperties.changeset(&1, &2, "select"),
          required: true
        )
        |> validate_required([:type])

      _ ->
        add_error(changeset, :type, "invalid DataView select queryable type")
    end
  end

  def unfold(queryable, resource_refs \\ {%{}, []})

  def unfold([%__MODULE__{} | _] = queryables, resource_refs) do
    Enum.reduce(queryables, resource_refs, &unfold/2)
  end

  def unfold([], resource_refs), do: resource_refs

  def unfold(queryable, {resource_refs, queryables}) do
    {resource_refs, unfolded} = QueryableProperties.unfold(queryable, resource_refs)
    {resource_refs, queryables ++ [unfolded]}
  end
end
