defmodule TdBg.Repo.Migrations.UpdateTemplateContentsFormat do
  use Ecto.Migration

  def change do
    do_changes("quality_control_versions", "df_content")
  end

  defp do_changes(table, column) do
    execute(
      """
      UPDATE
      #{table}
      SET #{column} = (
          SELECT jsonb_object_agg(key, jsonb_build_object('origin', 'user', 'value', value))
          FROM jsonb_each(#{column})
      ) WHERE #{column} != '{}' and #{column} IS NOT NULL;
      """,
      """
      UPDATE
      #{table}
      SET #{column} = (
        SELECT jsonb_object_agg(KEY, VALUE->'value')
          FROM jsonb_each(#{column})
      ) WHERE #{column} != '{}' AND #{column} IS NOT NULL;
      """
    )
  end
end
