defmodule TdQx.Repo.Migrations.CreateExecutionGroups do
  use Ecto.Migration

  def change do
    create table(:execution_groups) do
      add :df_content, :map

      timestamps(type: :utc_datetime_usec)
    end
  end
end
