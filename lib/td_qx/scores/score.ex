defmodule TdQx.Scores.Score do
  @moduledoc """
  Ecto Schema module for Score
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias TdQx.QualityControls.QualityControlVersion
  alias TdQx.Scores.ScoreContent
  alias TdQx.Scores.ScoreEvent
  alias TdQx.Scores.ScoreGroup

  @derive {Flop.Schema,
           adapter_opts: [
             join_fields: [
               quality_control_id: [
                 binding: :quality_control_version,
                 field: :id,
                 path: [:quality_control_version, :quality_control],
                 ecto_type: :integer
               ]
             ]
           ],
           filterable: [:quality_control_id],
           sortable: [
             :id,
             :execution_timestamp,
             :status,
             :result,
             :quality_control_status
           ],
           default_limit: 20}

  schema "scores" do
    field :execution_timestamp, :utc_datetime_usec
    field :details, :map, default: %{}
    field :latest_event_message, :string, virtual: true

    field :score_type, :string
    field :quality_control_status, :string
    embeds_one :score_content, ScoreContent, on_replace: :delete

    belongs_to :quality_control_version, QualityControlVersion
    belongs_to :group, ScoreGroup

    has_many :events, ScoreEvent

    field :status, :string, virtual: true
    field :result, :map, virtual: true
    timestamps type: :utc_datetime_usec
  end

  @doc false
  def create_grouped_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:quality_control_version_id, :group_id])
    |> put_assoc(:events, [%ScoreEvent{type: "PENDING"}])
    |> validate_required([:quality_control_version_id, :group_id])
  end

  @doc false
  def suceedded_changeset(%__MODULE__{score_type: score_type} = score, attrs) do
    score_content = ScoreContent.from_result(attrs, score_type)

    attrs = Map.put(attrs, "score_content", score_content)

    score
    |> cast(attrs, [
      :execution_timestamp,
      :details
    ])
    |> cast_embed(:score_content,
      with: &ScoreContent.changeset(&1, &2, score_type),
      required: true
    )
    |> validate_required([
      :execution_timestamp
    ])
  end

  @doc false
  def failed_changeset(%__MODULE__{} = score, attrs) do
    score
    |> cast(attrs, [
      :execution_timestamp,
      :details
    ])
    |> validate_required([
      :execution_timestamp
    ])
  end
end
