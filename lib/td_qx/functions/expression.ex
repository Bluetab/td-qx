defmodule TdQx.Functions.Expression do
  @moduledoc """
  Ecto Schema module for Function Expression
  """

  use Ecto.Schema

  alias TdQx.Functions.Function

  import Ecto.Changeset

  @constant_types %{type: :string, value: :string}
  @field_types %{type: :string, name: :string, dataset: :map}
  @function_types %{type: :string, name: :string, args: :map}
  @param_types %{id: :integer}

  @primary_key false
  embedded_schema do
    field :shape, :string
    field :value, :map
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:shape, :value])
    |> validate_required([:shape])
    |> validate_inclusion(:shape, ~w|constant function param field|)
    |> validate_value()
  end

  defp validate_value(changeset) do
    shape = get_change(changeset, :shape)
    value = get_change(changeset, :value)

    case changeset_by_shape(shape, value) do
      %{valid?: true} -> changeset
      _ -> add_error(changeset, :value, "invalid value for shape")
    end
  end

  defp changeset_by_shape("constant", value) do
    types = @constant_types

    {%{}, types}
    |> cast(value, Map.keys(types))
    |> validate_required(Map.keys(types))
    |> Function.validate_type()
  end

  defp changeset_by_shape("field", value) do
    types = @field_types

    {%{}, types}
    |> cast(value, Map.keys(types))
    |> validate_required(Map.keys(types))
    |> Function.validate_type()
  end

  defp changeset_by_shape("function", value) do
    types = @function_types

    {%{}, types}
    |> cast(value, Map.keys(types))
    |> validate_required(Map.keys(types))
    |> Function.validate_type()
  end

  defp changeset_by_shape("param", value) do
    types = @param_types

    {%{}, types}
    |> cast(value, Map.keys(types))
    |> validate_required(Map.keys(types))
  end

  defp changeset_by_shape(_, _) do
    nil
  end
end
