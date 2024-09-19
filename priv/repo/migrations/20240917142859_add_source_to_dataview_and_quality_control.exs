defmodule TdQx.Repo.Migrations.AddSourceToDataviewAndQualityControl do
  use Ecto.Migration

  def change do
    execute("DELETE FROM data_views CASCADE", "")
    execute("DELETE FROM executions CASCADE", "")
    execute("DELETE FROM quality_controls CASCADE", "")

    alter table(:data_views) do
      add(:source_id, :integer, null: false)
    end

    alter table(:quality_controls) do
      add(:source_id, :integer, null: false)
    end
  end
end
