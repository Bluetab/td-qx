defmodule TdQx.Repo.Migrations.CreateFunctions do
  use Ecto.Migration

  @valid_function_types "'boolean', 'string', 'numeric', 'date', 'timestamp', 'any'"

  def change do
    execute("DROP TYPE IF EXISTS function_type", "")

    execute(
      "CREATE TYPE function_type AS ENUM (#{@valid_function_types})",
      "DROP TYPE IF EXISTS function_type"
    )

    create table(:functions) do
      add :name, :string
      add :type, :function_type
      add :operator, :string
      add :description, :string
      add :params, {:array, :map}
      add :expression, :map

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:functions, [:name, :type])
  end
end
