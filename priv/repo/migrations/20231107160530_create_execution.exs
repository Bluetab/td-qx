defmodule TdQx.Repo.Migrations.CreateExecution do
  use Ecto.Migration

  def change do
    create table(:executions) do
      add(:status, :string)
      add(:execution_group_id, references("execution_groups"), on_delete: :nothing)
      add(:quality_control_id, references("quality_controls"), on_delete: :nothing)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:executions, [:execution_group_id])
    create index(:executions, [:quality_control_id])
  end
end
