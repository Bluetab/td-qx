defmodule TdQx.Executions.ExecutionEvent do
  @moduledoc """
  The ExecutionEvent schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "execution_events" do
    field :message, :string
    field :type, :string
    field :execution_id, :id

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(%__MODULE__{} = execution_events, attrs) do
    execution_events
    |> cast(attrs, [:type, :message])
    |> validate_required([:type, :message])
  end
end
