defmodule TdQx.Executions.Actions do
  @moduledoc """
  The Implementations Actions context.
  """

  use TdQxWeb, :controller

  alias TdQx.Executions.ExecutionGroup

  defdelegate authorize(action, user, params), to: TdQx.Executions.Policy

  def put_actions(conn, claims) do
    [:execute, :view]
    |> Enum.filter(&Bodyguard.permit?(TdQx.Executions, &1, claims, %ExecutionGroup{}))
    |> Map.new(fn
      action ->
        {action, %{method: "POST"}}
    end)
    |> then(&assign(conn, :actions, &1))
  end
end
