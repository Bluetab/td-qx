defmodule TdQx.Scores.ScoreEvent do
  @moduledoc """
  The ScoreEvent schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias TdQx.Scores.Score

  @valid_types [
    "QUEUED",
    "TIMEOUT",
    "PENDING",
    "STARTED",
    "INFO",
    "WARNING",
    "FAILED",
    "SUCCEEDED"
  ]

  schema "score_events" do
    field :message, :string
    field :type, :string
    field :ttl, :utc_datetime_usec

    belongs_to :score, Score

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(%__MODULE__{} = score_event, attrs) do
    score_event
    |> cast(attrs, [:type, :message, :score_id, :ttl])
    |> validate_required([:type, :score_id])
    |> validate_inclusion(:type, @valid_types)
    |> foreign_key_constraint(:score_id)
  end

  def valid_types, do: @valid_types
end
