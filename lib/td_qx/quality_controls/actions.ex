defmodule TdQx.QualityControls.Actions do
  @moduledoc """
  The Actions context for Quality Controls.
  """

  alias Plug.Conn
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
    "execute"
  ]

  def put_actions(conn, claims, quality_control) do
    @valid_actions
    |> Enum.filter(
      &(QualityControlWorkflow.valid_action?(quality_control, &1) and
          Bodyguard.permit?(TdQx.QualityControls, &1, claims, quality_control))
    )
    |> then(&Conn.assign(conn, :actions, &1))
  end
end
