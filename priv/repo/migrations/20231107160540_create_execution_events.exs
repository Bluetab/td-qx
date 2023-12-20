defmodule TdQx.Repo.Migrations.CreateExecutionEvents do
  use Ecto.Migration

  def change do
    create table(:execution_events) do
      add :type, :string
      add :message, :string
      add :execution_id, references(:executions, on_delete: :nothing)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:execution_events, [:execution_id])
  end
end
