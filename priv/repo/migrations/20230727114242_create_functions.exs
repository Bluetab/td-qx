defmodule TdQx.Repo.Migrations.CreateFunctions do
  use Ecto.Migration

  def change do
    create table(:functions) do
      add :name, :string
      add :type, :string
      add :class, :string
      add :operator, :string
      add :description, :string
      add :params, {:array, :map}
      add :expression, :map

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:functions, [:name, :type])
  end
end
