defmodule TdQx.Functions do
  @moduledoc """
  The Functions context.
  """

  import Ecto.Query, warn: false
  alias TdQx.Repo

  alias TdQx.Functions.Function

  require Logger

  defdelegate authorize(action, user, params), to: __MODULE__.Policy

  @doc """
  Returns the list of functions.

  ## Examples

      iex> list_functions()
      [%Function{}, ...]

  """
  def list_functions do
    Function
    |> order_by([f], f.id)
    |> Repo.all()
  end

  @doc """
  Gets a single function.

  Raises `Ecto.NoResultsError` if the Function does not exist.

  ## Examples

      iex> get_function!(123)
      %Function{}

      iex> get_function!(456)
      ** (Ecto.NoResultsError)

  """
  def get_function!(id), do: Repo.get!(Function, id)

  @doc """
  Gets a single function by name and type.

  Raises `Ecto.NoResultsError` if the Function does not exist.

  ## Examples

      iex> get_function_by_name_type!("name", "boolean")
      %Function{}

      iex> get_function_by_name_type!("inexistent", "boolean")
      ** (Ecto.NoResultsError)

  """
  def get_function_by_name_type(name, type), do: Repo.get_by(Function, name: name, type: type)

  @doc """
  Creates a function.

  ## Examples

      iex> create_function(%{field: value})
      {:ok, %Function{}}

      iex> create_function(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_function(attrs \\ %{}) do
    %Function{}
    |> Function.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a function.

  ## Examples

      iex> update_function(function, %{field: new_value})
      {:ok, %Function{}}

      iex> update_function(function, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_function(%Function{} = function, attrs) do
    function
    |> Function.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a function.

  ## Examples

      iex> delete_function(function)
      {:ok, %Function{}}

      iex> delete_function(function)
      {:error, %Ecto.Changeset{}}

  """
  def delete_function(%Function{} = function) do
    Repo.delete(function)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking function changes.

  ## Examples

      iex> change_function(function)
      %Ecto.Changeset{data: %Function{}}

  """
  def change_function(%Function{} = function, attrs \\ %{}) do
    Function.changeset(function, attrs)
  end

  def load_from_file!(path) do
    if File.regular?(path) do
      ts = DateTime.utc_now()

      functions =
        path
        |> File.read!()
        |> Jason.decode!()
        |> Enum.map(fn function ->
          %{
            name: Map.get(function, "name"),
            type: Map.get(function, "type"),
            class: Map.get(function, "class"),
            operator: Map.get(function, "operator"),
            description: Map.get(function, "description"),
            params: parse_params(function),
            inserted_at: ts,
            updated_at: ts
          }
        end)

      case Repo.insert_all(Function, functions, on_conflict: :nothing) do
        {0, _} -> Logger.info("No new functions'")
        {count, _} -> Logger.info("Loaded #{count} functions")
      end
    else
      Logger.warning("File #{path} does not exist")
    end
  end

  defp parse_params(%{"params" => params}) do
    params
    |> Enum.map(fn param ->
      %TdQx.Functions.Param{
        name: Map.get(param, "name"),
        type: Map.get(param, "type"),
        description: Map.get(param, "description")
      }
    end)
  end

  defp parse_params(_), do: []
end
