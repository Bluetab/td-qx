defmodule TdQx.Functions do
  @moduledoc """
  The Functions context.
  """

  import Ecto.Query, warn: false
  alias TdQx.Repo

  alias TdQx.Functions.Function

  defdelegate authorize(action, user, params), to: __MODULE__.Policy

  @doc """
  Returns the list of functions.

  ## Examples

      iex> list_functions()
      [%Function{}, ...]

  """
  def list_functions do
    Repo.all(Function)
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
end
