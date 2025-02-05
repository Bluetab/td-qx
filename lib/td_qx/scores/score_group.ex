defmodule TdQx.Scores.ScoreGroup do
  @moduledoc """
  The ScoreGroup schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias TdDfLib.Validation
  alias TdQx.Scores.Score

  schema "score_groups" do
    field :dynamic_content, :map
    field :df_type, :string
    field :created_by, :integer

    field :status_summary, :map, virtual: true

    has_many :scores, Score, foreign_key: :group_id

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:dynamic_content, :df_type, :created_by])
    |> validate_required([:dynamic_content, :df_type, :created_by])
    |> validate_content()
  end

  defp validate_content(%{valid?: true} = changeset) do
    df_type = get_field(changeset, :df_type)

    validate_change(
      changeset,
      :dynamic_content,
      Validation.validator(df_type)
    )
  end

  defp validate_content(changeset), do: changeset
end
