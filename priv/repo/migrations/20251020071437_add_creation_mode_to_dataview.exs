defmodule TdQx.Repo.Migrations.AddCreationModeToDataview do
  use Ecto.Migration

  def change do
    alter table(:data_views) do
      add(:mode, :string, size: 255, null: false, default: "advanced")
    end
  end
end
