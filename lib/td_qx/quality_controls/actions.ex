defmodule TdQx.QualityControls.Actions do
  @moduledoc """
  The Actions context for Quality Controls.
  """

  alias Plug.Conn
  alias TdQx.QualityControls.QualityControl
  alias TdQx.QualityControls.QualityControlVersion
  alias TdQx.QualityControlWorkflow

  @valid_actions [
    "send_to_approval",
    "send_to_draft",
    "reject",
    "publish",
    "deprecate",
    "restore",
    "edit",
    "create_draft",
    "toggle_active",
    "delete_score",
    "update_main",
    "execute",
    "delete"
  ]

  def put_actions(conn, claims, quality_control_or_version) do
    @valid_actions
    |> Enum.filter(
      &(QualityControlWorkflow.valid_action?(quality_control_or_version, &1) and
          permit?(quality_control_or_version, &1, claims))
    )
    |> then(&Conn.assign(conn, :actions, &1))
  end

  defp permit?(%QualityControlVersion{quality_control: quality_control}, action, claims) do
    Bodyguard.permit?(TdQx.QualityControls, action, claims, quality_control)
  end

  defp permit?(%QualityControl{} = quality_control, action, claims) do
    Bodyguard.permit?(TdQx.QualityControls, action, claims, quality_control)
  end
end
