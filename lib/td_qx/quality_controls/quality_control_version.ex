defmodule TdQx.QualityControls.QualityControlVersion do
  @moduledoc """
  Ecto Schema module for QualityControlVersion
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias TdDfLib.Validation
  alias TdQx.QualityControls
  alias TdQx.QualityControls.ControlProperties
  alias TdQx.QualityControls.QualityControl
  alias TdQx.QualityControls.QualityControlVersion
  alias TdQx.QualityControls.ScoreCriteria

  @valid_statuses [
    "draft",
    "pending_approval",
    "rejected",
    "published",
    "versioned",
    "deprecated"
  ]
  @valid_actions [
    "send_to_approval",
    "send_to_draft",
    "reject",
    "publish",
    "deprecate",
    "restore"
  ]
  @valid_actions_statuses [
    {"draft", "send_to_approval"},
    {"draft", "publish"},
    {"pending_approval", "publish"},
    {"pending_approval", "reject"},
    {"rejected", "send_to_draft"},
    {"published", "deprecate"},
    {"deprecated", "restore"}
  ]

  @valid_control_modes ["deviation", "percentage", "count"]

  schema "quality_control_versions" do
    field(:name, :string)
    field(:status, :string, default: "draft")
    field(:version, :integer, default: 1)

    field(:dynamic_content, :map)
    field(:df_type, :string)

    field(:control_mode, :string)

    belongs_to(:quality_control, QualityControl)
    embeds_one(:score_criteria, ScoreCriteria, on_replace: :delete)
    embeds_one(:control_properties, ControlProperties, on_replace: :delete)

    field(:queries, {:array, :map}, virtual: true)
    field(:latest, :boolean, virtual: true, default: false)
    field(:latest_score, :map, virtual: true)
    field(:final_score, :map, virtual: true)

    timestamps(type: :utc_datetime_usec)
  end

  def valid_actions, do: @valid_actions
  def valid_actions_statuses, do: @valid_actions_statuses
  def valid_statuses, do: @valid_statuses

  @doc false
  def create_changeset(%{id: quality_control_id} = quality_control, attrs, version) do
    changeset =
      cast(%QualityControlVersion{}, attrs, [
        :name,
        :dynamic_content,
        :df_type,
        :control_mode,
        :status
      ])

    control_mode = get_field(changeset, :control_mode)

    changeset
    |> cast_embed(:score_criteria, with: &ScoreCriteria.changeset(&1, &2, control_mode))
    |> cast_embed(:control_properties, with: &ControlProperties.changeset(&1, &2, control_mode))
    |> put_assoc(:quality_control, quality_control)
    |> put_change(:version, version)
    |> validate_required([
      :name,
      :status,
      :version,
      :control_mode
    ])
    |> unique_constraint(:unique_name_status, name: "quality_control_versions_name_status_index")
    |> validate_unique_name(quality_control_id)
    |> validate_inclusion(:status, ["draft", "published"])
    |> validate_inclusion(:control_mode, @valid_control_modes)
    |> maybe_validate_published_status()
  end

  def valid_publish_version(
        %QualityControlVersion{
          control_properties: control_properties,
          score_criteria: score_criteria
        } =
          version
      ) do
    control_properties = ControlProperties.to_json(control_properties)
    score_criteria = ScoreCriteria.to_json(score_criteria)

    version
    |> cast(
      %{
        control_properties: control_properties,
        score_criteria: score_criteria
      },
      [
        :name,
        :dynamic_content,
        :df_type,
        :control_mode,
        :status
      ]
    )
    |> validate_required([
      :name,
      :status,
      :version
    ])
    |> validate_publish_changeset()
    |> Map.get(:valid?)
  end

  @doc false
  def status_changeset(quality_control_version, status) do
    quality_control_version
    |> cast(%{status: status}, [:status])
    |> validate_required([:status])
    |> validate_inclusion(:status, @valid_statuses)
  end

  @doc false
  def update_draft_changeset(
        %QualityControlVersion{quality_control_id: quality_control_id} = quality_control_version,
        attrs
      ) do
    changeset =
      cast(quality_control_version, attrs, [
        :name,
        :dynamic_content,
        :df_type,
        :control_mode
      ])

    control_mode = get_field(changeset, :control_mode)

    changeset
    |> cast_embed(:score_criteria, with: &ScoreCriteria.changeset(&1, &2, control_mode))
    |> cast_embed(:control_properties, with: &ControlProperties.changeset(&1, &2, control_mode))
    |> validate_required([
      :name,
      :status,
      :version
    ])
    |> unique_constraint(:unique_name_status, name: "quality_control_versions_name_status_index")
    |> validate_unique_name(quality_control_id)
  end

  defp maybe_validate_published_status(%{changes: %{status: "published"}} = changeset),
    do: validate_publish_changeset(changeset)

  defp maybe_validate_published_status(changeset), do: changeset

  defp validate_unique_name(%{valid?: false} = changeset, _), do: changeset

  defp validate_unique_name(changeset, quality_control_id) do
    name = get_field(changeset, :name)

    case QualityControls.count_unique_name(name, quality_control_id) do
      0 -> changeset
      _ -> add_error(changeset, :name, "duplicated_name")
    end
  end

  def validate_publish_changeset(changeset) do
    control_mode = get_field(changeset, :control_mode)

    changeset
    |> validate_required([
      :name,
      :status,
      :version,
      :dynamic_content,
      :df_type,
      :control_mode
    ])
    |> cast_embed(:score_criteria,
      with: &ScoreCriteria.changeset(&1, &2, control_mode),
      required: true
    )
    |> cast_embed(:control_properties,
      with: &ControlProperties.changeset(&1, &2, control_mode),
      required: true
    )
    |> validate_template()
  end

  defp validate_template(%Ecto.Changeset{valid?: true} = changeset) do
    template_name = get_field(changeset, :df_type)
    dynamic_content = get_field(changeset, :dynamic_content)

    validator = Validation.validator(template_name)

    :dynamic_content
    |> validator.(dynamic_content)
    |> case do
      [] ->
        changeset

      errors ->
        Enum.reduce(
          errors,
          changeset,
          fn {key, {message, keys}}, changeset -> add_error(changeset, key, message, keys) end
        )
    end
  end

  defp validate_template(changeset), do: changeset
end
