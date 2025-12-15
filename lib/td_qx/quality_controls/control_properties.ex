defmodule TdQx.QualityControls.ControlProperties do
  @moduledoc """
  Ecto Schema module for QualityControl ControlProperties
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdQx.QualityControls.ControlProperties.Count
  alias TdQx.QualityControls.ControlProperties.Ratio

  @primary_key false
  @derive Jason.Encoder
  embedded_schema do
    embeds_one(:count, Count, on_replace: :delete)
    embeds_one(:ratio, Ratio, on_replace: :delete)
  end

  def changeset(%__MODULE__{} = struct, %{} = params, control_mode) do
    prop_type = control_mode_to_properties(control_mode)
    prop_params = %{prop_type => params}

    struct
    |> cast(prop_params, [])
    |> cast_control_properties_embed(prop_type)
  end

  def to_json(%__MODULE__{count: %Count{} = count}),
    do: Count.to_json(count)

  def to_json(%__MODULE__{ratio: %Ratio{} = ratio}),
    do: Ratio.to_json(ratio)

  def to_json(_), do: nil

  defp control_mode_to_properties("count"), do: "count"

  defp control_mode_to_properties(type) when type in ["deviation", "error_count", "percentage"],
    do: "ratio"

  defp control_mode_to_properties(_), do: "invalid"

  defp cast_control_properties_embed(changeset, "count"),
    do: cast_embed(changeset, :count, with: &Count.changeset/2)

  defp cast_control_properties_embed(changeset, "ratio"),
    do: cast_embed(changeset, :ratio, with: &Ratio.changeset/2)

  defp cast_control_properties_embed(changeset, _),
    do: add_error(changeset, :control_mode, "invalid")

  def enrich_resources(
        %__MODULE__{count: %Count{} = count} = control_properties,
        enrich_fun
      ),
      do: %{
        control_properties
        | count: Count.enrich_resources(count, enrich_fun)
      }

  def enrich_resources(%__MODULE__{ratio: %Ratio{} = ratio} = control_properties, enrich_fun),
    do: %{control_properties | ratio: Ratio.enrich_resources(ratio, enrich_fun)}
end
