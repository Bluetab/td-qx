defmodule TdQx.Repo.Migrations.CreateQualityControls do
  use Ecto.Migration

  def change do
    create table(:quality_controls) do
      add(:domain_ids, {:array, :bigint}, null: false)
      add(:source_id, :integer, null: false)
      add(:active, :boolean, default: true, null: false)

      timestamps(type: :utc_datetime_usec)
    end
  end
end
