defmodule TdQx.QualityControls.QualityControlVersion do
  @moduledoc """
  Ecto Schema module for QualityControlVersion
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias TdDfLib.Validation
  alias TdQx.DataViews.Resource
  alias TdQx.Expressions.Clause

  alias TdQx.QualityControls
  alias TdQx.QualityControls.QualityControl
  alias TdQx.QualityControls.QualityControlVersion
  alias TdQx.QualityControls.ResultCriteria

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

  schema "quality_control_versions" do
    belongs_to(:quality_control, QualityControl)
    field(:name, :string)
    field(:status, :string, default: "draft")
    field(:version, :integer, default: 1)

    field(:df_content, :map)
    field(:df_type, :string)

    embeds_one(:result_criteria, ResultCriteria, on_replace: :delete)
    field(:result_type, :string)

    embeds_one(:resource, Resource, on_replace: :delete)
    embeds_many(:validation, Clause, on_replace: :delete)

    timestamps()
  end

  def valid_actions, do: @valid_actions
  def valid_actions_statuses, do: @valid_actions_statuses
  def valid_statuses, do: @valid_statuses

  @doc false
  def create_changeset(%{id: quality_control_id} = quality_control, attrs, version) do
    changeset =
      cast(%QualityControlVersion{}, attrs, [
        :name,
        :df_content,
        :df_type,
        :result_type,
        :status
      ])

    result_type = get_field(changeset, :result_type)

    changeset
    |> cast_embed(:result_criteria, with: &ResultCriteria.changeset(&1, &2, result_type))
    |> cast_embed(:resource, with: &Resource.changeset/2)
    |> cast_embed(:validation, with: &Clause.changeset/2)
    |> put_assoc(:quality_control, quality_control)
    |> put_change(:version, version)
    |> validate_required([
      :name,
      :status,
      :version
    ])
    |> unique_constraint(:unique_name_status, name: "quality_control_versions_name_status_index")
    |> validate_unique_name(quality_control_id)
    |> validate_inclusion(:status, ["draft", "published"])
    |> maybe_validate_published_status()
  end

  def valid_publish_version(%QualityControlVersion{} = version) do
    version
    |> cast(%{}, [
      :name,
      :df_content,
      :df_type,
      :result_type,
      :status
    ])
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
        :df_content,
        :df_type,
        :result_type
      ])

    result_type = get_field(changeset, :result_type)

    changeset
    |> cast_embed(:result_criteria, with: &ResultCriteria.changeset(&1, &2, result_type))
    |> cast_embed(:resource, with: &Resource.changeset/2)
    |> cast_embed(:validation, with: &Clause.changeset/2)
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
    result_type = get_field(changeset, :result_type)

    changeset
    |> validate_required([
      :name,
      :status,
      :version,
      :df_content,
      :df_type,
      :result_type
    ])
    |> cast_embed(:result_criteria,
      with: &ResultCriteria.changeset(&1, &2, result_type),
      required: true
    )
    |> cast_embed(:resource, with: &Resource.changeset/2, required: true)
    |> cast_embed(:validation, with: &Clause.changeset/2, required: true)
    |> validate_template()
  end

  defp validate_template(%Ecto.Changeset{valid?: true} = changeset) do
    template_name = get_field(changeset, :df_type)
    content = get_field(changeset, :df_content)

    validator = Validation.validator(template_name)

    :df_content
    |> validator.(content)
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
