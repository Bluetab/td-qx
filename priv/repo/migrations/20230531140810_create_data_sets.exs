defmodule TdQx.Repo.Migrations.CreateDataSets do
  use Ecto.Migration

  def change do
    create table(:data_sets) do
      add :name, :string
      add :data_structure_id, :bigint

      timestamps()
    end
  end
end