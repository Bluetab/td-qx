defmodule TdQx.Executions.ExecutionGroup do
  @moduledoc """
  The ExecutionGroup schema.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias TdDfLib.Validation

  schema "execution_groups" do
    field :df_content, :map
    field :filters, :map, virtual: true

    has_many :executions, TdQx.Executions.Execution

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:df_content])
    |> validate_required([:df_content])
    |> validate_change(:df_content, &Validation.validate_safe/2)
  end
end
