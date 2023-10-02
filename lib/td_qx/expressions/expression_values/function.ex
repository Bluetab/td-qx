defmodule TdQx.Expressions.ExpressionValues.Function do
  @moduledoc """
  Ecto Schema module for ExpressionValue of shape Function
  """

  use Ecto.Schema

  alias TdQx.Expressions.ExpressionValues.FunctionArg
  alias TdQx.Functions
  alias TdQx.Functions.Function

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :type, :string
    field :name, :string
    embeds_many(:args, FunctionArg, on_replace: :delete)
  end

  def changeset(%__MODULE__{} = struct, %{} = params, function_class \\ nil) do
    changeset = cast(struct, params, [:type, :name])

    name = get_field(changeset, :name)
    type = get_field(changeset, :type)

    function = get_function(name, type)
    function_params = get_function_params(function)

    params = cast_args(params, function_params)

    struct
    |> cast(params, [:type, :name])
    |> cast_embed(:args, with: &FunctionArg.changeset/2)
    |> validate_function(function)
    |> validate_function_class(function, function_class)
    |> validate_required([:type, :name])
    |> Function.validate_type()
  end

  defp get_function_params(%Function{params: params}), do: params
  defp get_function_params(_), do: []

  defp get_function(name, type) when is_binary(name) and is_binary(type),
    do: Functions.get_function_by_name_type(name, type)

  defp get_function(_, _), do: nil

  defp validate_function(changeset, %Function{}), do: changeset

  defp validate_function(changeset, _),
    do: add_error(changeset, :function, "function does not exist")

  defp validate_function_class(changeset, _, nil), do: changeset

  defp validate_function_class(changeset, %Function{class: class}, class), do: changeset

  defp validate_function_class(changeset, _, _),
    do: add_error(changeset, :class, "invalid function class for aggregator function")

  defp cast_args(%{"args" => args} = params, function_params),
    do: do_cast_args(params, args, function_params, "args")

  defp cast_args(%{args: args} = params, function_params),
    do: do_cast_args(params, args, function_params, :args)

  defp cast_args(params, _), do: params

  defp do_cast_args(params, args, function_params, original_key) do
    function_param_names = Enum.map(function_params, & &1.name)

    args =
      args
      |> Enum.map(fn {name, expression} ->
        %{
          name: maybe_atom_to_string(name),
          expression: expression
        }
      end)
      |> Enum.filter(fn %{name: name} -> name in function_param_names end)

    Map.put(params, original_key, args)
  end

  defp maybe_atom_to_string(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp maybe_atom_to_string(not_atom), do: not_atom
end
