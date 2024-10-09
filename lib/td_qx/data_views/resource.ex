defmodule TdQx.DataViews.Resource do
  @moduledoc """
  Ecto Schema module for DataViews Resources
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdQx.DataViews
  alias TdQx.DataViews.Queryable

  @valid_types ~w|data_structure reference_dataset data_view|

  @primary_key false
  embedded_schema do
    field(:id, :integer)
    field(:type, :string)
    field(:embedded, :map, virtual: true)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:id, :type])
    |> validate_required([:id, :type])
    |> validate_inclusion(:type, @valid_types)
  end

  def unfold(
        %__MODULE__{type: type, id: resource_id},
        %Queryable{id: id, alias: queryable_alias}
      ) do
    resource_ref = %{
      type: type,
      id: resource_id,
      alias: queryable_alias
    }

    resource_value =
      case type do
        "data_view" ->
          resource_id
          |> DataViews.get_data_view!()
          |> DataViews.DataView.unfold()

        _ ->
          nil
      end

    {resource_value, id, resource_ref}
  end
end
