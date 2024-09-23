defmodule TdQx.DataViews.QueryableProperties.Join do
  @moduledoc """
  Ecto Schema module for DataViews QueryablesProperties Join
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdQx.DataViews.Resource
  alias TdQx.Expressions.Clause

  @valid_types ~w|inner full_outer left right|

  @primary_key false
  embedded_schema do
    embeds_one(:resource, Resource, on_replace: :delete)
    embeds_many(:clauses, Clause, on_replace: :delete)
    field(:type, :string, default: "inner")
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:type])
    |> cast_embed(:resource, with: &Resource.changeset/2, required: true)
    |> cast_embed(:clauses, with: &Clause.changeset/2, required: true)
    |> validate_required([:type])
    |> validate_inclusion(:type, @valid_types)
  end

  def unfold(
        %__MODULE__{type: type, resource: resource, clauses: clauses},
        queryable,
        resource_refs
      ) do
    {resource_refs, resource, resource_ref} = Resource.unfold(resource, queryable, resource_refs)

    {resource_refs,
     %{
       __type__: "join",
       type: type,
       resource: resource,
       resource_ref: resource_ref,
       clauses: Clause.unfold(clauses)
     }}
  end
end
