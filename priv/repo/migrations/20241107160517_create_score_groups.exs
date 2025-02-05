defmodule TdQx.Repo.Migrations.CreateScoreGroups do
  use Ecto.Migration

  def change do
    create table(:score_groups) do
      add :dynamic_content, :map
      add :df_type, :string
      add :created_by, :bigint

      timestamps(type: :utc_datetime_usec)
    end
  end
end
