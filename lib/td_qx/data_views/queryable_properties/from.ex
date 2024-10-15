defmodule TdQx.DataViews.QueryableProperties.From do
  @moduledoc """
  Ecto Schema module for DataViews Queryables Properties From
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdQx.DataViews.Resource

  @primary_key false
  embedded_schema do
    embeds_one(:resource, Resource, on_replace: :delete)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [])
    |> cast_embed(:resource, with: &Resource.changeset/2, required: true)
  end

  def unfold(%__MODULE__{resource: resource}, queryable) do
    {resource, id, resource_ref} = Resource.unfold(resource, queryable)
    {{id, resource_ref}, %{__type__: "from", resource: resource, resource_ref: id}}
  end
end
