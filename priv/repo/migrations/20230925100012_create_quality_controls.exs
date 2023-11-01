defmodule TdQx.Repo.Migrations.CreateQualityControls do
  use Ecto.Migration

  def change do
    create table(:quality_controls) do
      add(:domain_ids, {:array, :bigint}, null: false)

      timestamps()
    end
  end
end
