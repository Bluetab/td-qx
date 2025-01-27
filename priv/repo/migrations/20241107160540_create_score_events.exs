defmodule TdQx.Repo.Migrations.CreateExecutionEvents do
  use Ecto.Migration

  def change do
    create table(:score_events) do
      add :type, :string
      add :message, :string
      add :score_id, references(:scores, on_delete: :delete_all)
      add :ttl, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:score_events, [:score_id])
  end
end
