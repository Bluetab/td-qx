defmodule TdQx.Repo.Migrations.CreateExecution do
  use Ecto.Migration

  def change do
    create table(:scores) do
      add :execution_timestamp, :utc_datetime_usec
      add :details, :map, default: %{}
      add :score_type, :string
      add :score_content, :map

      add :quality_control_version_id,
          references(:quality_control_versions, on_delete: :delete_all)

      add :quality_control_status, :string

      add :group_id, references(:score_groups, on_delete: :delete_all)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:scores, [:group_id])
    create index(:scores, [:quality_control_version_id])
  end
end
