defmodule TdQx.Executions do
  @moduledoc """
  The Executions context.
  """

  import Ecto.Query, warn: false

  alias TdQx.Executions.Execution
  alias TdQx.Executions.ExecutionGroup

  alias TdQx.Repo

  defdelegate authorize(action, user, params), to: __MODULE__.Policy

  @doc """
  Returns the list of execution_groups.

  ## Examples

      iex> list_execution_groups()
      [%ExecutionGroup{}, ...]

  """
  def list_execution_groups do
    ExecutionGroup
    |> preload([:executions])
    |> Repo.all()
  end

  @doc """
  Gets a single execution_groups.

  Raises `Ecto.NoResultsError` if the Execution groups does not exist.

  ## Examples

      iex> get_execution_group(123)
      %ExecutionGroup{}

      iex> get_execution_group(456)
      ** (Ecto.NoResultsError)

  """
  def get_execution_group(id) do
    ExecutionGroup
    |> where([eg], eg.id == ^id)
    |> preload([
      :executions,
      executions: [
        :quality_control,
        quality_control: [:published_version, published_version: :quality_control]
      ]
    ])
    |> Repo.one()
  end

  @doc """
  Creates a execution_groups.

  ## Examples

      iex> create_execution_group(%{field: value})
      {:ok, %ExecutionGroup{}}

      iex> create_execution_group(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_execution_group([], _), do: {:error, :not_found}

  def create_execution_group([%{"id" => _id} | _] = quality_controls, params) do
    quality_controls
    |> Enum.map(&%{id: &1["id"]})
    |> create_execution_group(params)
  end

  def create_execution_group(quality_controls, %{"df_content" => df_content}) do
    changeset = ExecutionGroup.changeset(%ExecutionGroup{}, %{df_content: df_content})

    with {:ok, %{id: execution_group_id} = execution_group} <- Repo.insert(changeset) do
      Enum.each(quality_controls, &insert_execution(&1, execution_group_id))
      {:ok, execution_group}
    end
  end

  defp insert_execution(%{id: id}, execution_group_id),
    do: insert_execution(id, execution_group_id)

  defp insert_execution(%{"id" => id}, execution_group_id),
    do: insert_execution(id, execution_group_id)

  defp insert_execution(id, execution_group_id) do
    %Execution{}
    |> Execution.changeset(%{
      execution_group_id: execution_group_id,
      quality_control_id: id
    })
    |> Repo.insert()
  end

  @doc """
  Updates a execution_groups.

  ## Examples

      iex> update_execution_groups(execution_groups, %{field: new_value})
      {:ok, %ExecutionGroup{}}

      iex> update_execution_groups(execution_groups, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_execution_groups(%ExecutionGroup{} = execution_groups, attrs) do
    execution_groups
    |> ExecutionGroup.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a execution_groups.

  ## Examples

      iex> delete_execution_groups(execution_groups)
      {:ok, %ExecutionGroup{}}

      iex> delete_execution_groups(execution_groups)
      {:error, %Ecto.Changeset{}}

  """
  def delete_execution_groups(%ExecutionGroup{} = execution_groups) do
    Repo.delete(execution_groups)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking execution_groups changes.

  ## Examples

      iex> change_execution_groups(execution_groups)
      %Ecto.Changeset{data: %ExecutionGroup{}}

  """
  def change_execution_groups(%ExecutionGroup{} = execution_groups, attrs \\ %{}) do
    ExecutionGroup.changeset(execution_groups, attrs)
  end

  alias TdQx.Executions.Execution

  @doc """
  Returns the list of execution.

  ## Examples

      iex> list_execution()
      [%Execution{}, ...]

  """
  def list_execution do
    Repo.all(Execution)
  end

  @doc """
  Gets a single execution.

  Raises `Ecto.NoResultsError` if the Execution does not exist.

  ## Examples

      iex> get_execution!(123)
      %Execution{}

      iex> get_execution!(456)
      ** (Ecto.NoResultsError)

  """
  def get_execution!(id), do: Repo.get!(Execution, id)

  @doc """
  Creates a execution.

  ## Examples

      iex> create_execution(%{field: value})
      {:ok, %Execution{}}

      iex> create_execution(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_execution(attrs \\ %{}) do
    %Execution{}
    |> Execution.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a execution.

  ## Examples

      iex> update_execution(execution, %{field: new_value})
      {:ok, %Execution{}}

      iex> update_execution(execution, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_execution(%Execution{} = execution, attrs) do
    execution
    |> Execution.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a execution.

  ## Examples

      iex> delete_execution(execution)
      {:ok, %Execution{}}

      iex> delete_execution(execution)
      {:error, %Ecto.Changeset{}}

  """
  def delete_execution(%Execution{} = execution) do
    Repo.delete(execution)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking execution changes.

  ## Examples

      iex> change_execution(execution)
      %Ecto.Changeset{data: %Execution{}}

  """
  def change_execution(%Execution{} = execution, attrs \\ %{}) do
    Execution.changeset(execution, attrs)
  end

  alias TdQx.Executions.ExecutionEvent

  @doc """
  Returns the list of execution_events.

  ## Examples

      iex> list_execution_events()
      [%ExecutionEvents{}, ...]

  """
  def list_execution_events do
    Repo.all(ExecutionEvent)
  end

  @doc """
  Gets a single execution_events.

  Raises `Ecto.NoResultsError` if the Execution events does not exist.

  ## Examples

      iex> get_execution_events!(123)
      %ExecutionEvent{}

      iex> get_execution_events!(456)
      ** (Ecto.NoResultsError)

  """
  def get_execution_events!(id), do: Repo.get!(ExecutionEvent, id)

  @doc """
  Creates a execution_events.

  ## Examples

      iex> create_execution_events(%{field: value})
      {:ok, %ExecutionEvent{}}

      iex> create_execution_events(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_execution_events(attrs \\ %{}) do
    %ExecutionEvent{}
    |> ExecutionEvent.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a execution_events.

  ## Examples

      iex> update_execution_events(execution_events, %{field: new_value})
      {:ok, %ExecutionEvent{}}

      iex> update_execution_events(execution_events, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_execution_events(%ExecutionEvent{} = execution_events, attrs) do
    execution_events
    |> ExecutionEvent.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a execution_events.

  ## Examples

      iex> delete_execution_events(execution_events)
      {:ok, %ExecutionEvent{}}

      iex> delete_execution_events(execution_events)
      {:error, %Ecto.Changeset{}}

  """
  def delete_execution_events(%ExecutionEvent{} = execution_events) do
    Repo.delete(execution_events)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking execution_events changes.

  ## Examples

      iex> change_execution_events(execution_events)
      %Ecto.Changeset{data: %ExecutionEvents}}

  """
  def change_execution_events(%ExecutionEvent{} = execution_events, attrs \\ %{}) do
    ExecutionEvent.changeset(execution_events, attrs)
  end
end
