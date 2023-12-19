defmodule TdQx.Executions.Execution do
  @moduledoc """
  The Executions schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @valid_statuses [
    "pending",
    "started",
    "succeded",
    "failed"
  ]

  schema "executions" do
    field :status, :string, default: "pending"
    belongs_to :execution_group, TdQx.Executions.ExecutionGroup
    belongs_to :quality_control, TdQx.QualityControls.QualityControl

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = struct, attrs) do
    struct
    |> cast(attrs, [:execution_group_id, :quality_control_id, :status, :inserted_at, :updated_at])
    |> validate_required([
      :execution_group_id,
      :quality_control_id,
      :status
    ])
    |> validate_inclusion(:status, @valid_statuses)
    |> foreign_key_constraint(:quality_control_id)
  end
end
