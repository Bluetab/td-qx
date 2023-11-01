defmodule TdQx.Repo.Migrations.CreateQualityControlVersions do
  use Ecto.Migration

  def change do
    create table(:quality_control_versions) do
      add :quality_control_id, references(:quality_controls, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :status, :string, null: false
      add :version, :integer, null: false
      add :df_content, :map
      add :df_type, :string
      add :result_type, :string
      add :result_criteria, :map
      add :resource, :map
      add :validation, :map

      timestamps()
    end

    create index(:quality_control_versions, [:quality_control_id])
    create unique_index(:quality_control_versions, [:quality_control_id, :version])

    create unique_index(:quality_control_versions, [:quality_control_id, :status],
             where: "status <> 'versioned'"
           )

    create unique_index(:quality_control_versions, [:name, :status],
             where: """
              status not in ('deprecated', 'versioned')
             """
           )
  end
end
