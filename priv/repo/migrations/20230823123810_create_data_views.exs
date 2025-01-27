defmodule TdQx.Repo.Migrations.CreateDataViews do
  use Ecto.Migration

  def change do
    create table(:data_views) do
      add :name, :string, null: false
      add :created_by_id, :integer, null: false
      add :description, :string
      add :queryables, {:array, :map}
      add :select, :map
      add :source_id, :integer, null: false

      timestamps(type: :utc_datetime_usec)
    end
  end
end
