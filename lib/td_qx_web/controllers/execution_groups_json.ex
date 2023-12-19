defmodule TdQxWeb.ExecutionGroupsJSON do
  alias TdQx.Executions.ExecutionGroup

  @doc """
  Renders a list of execution_groups.
  """
  def index(%{execution_groups: execution_groups}) do
    %{
      data:
        for(%ExecutionGroup{} = execution_group <- execution_groups, do: data(execution_group))
    }
  end

  def show(%{execution_groups: %{executions: executions} = execution_groups}) do
    result =
      data(execution_groups)
      |> Map.merge(%{
        executions: executions
      })

    %{data: result}
  end

  def show(%{execution_group: %{executions: executions} = execution_group}) do
    result =
      data(execution_group)
      |> Map.merge(%{
        executions: for(execution <- executions, do: show_execution(execution))
      })

    %{data: result}
  end

  defp data(%{id: id, inserted_at: inserted_at, executions: executions}) do
    statuses = ["pending", "started", "succeeded", "failed"]

    counts =
      Enum.reduce(statuses, %{}, fn status, acc ->
        count = Enum.count(executions, &(&1.status == status))
        Map.put(acc, String.to_atom("#{status}_count"), count)
      end)

    Map.merge(%{id: id, created: inserted_at}, counts)
  end

  defp data(_), do: %{id: nil, df_content: nil, executions: nil}

  defp show_execution(%{
         id: id,
         status: status,
         quality_control: %{published_version: %{name: name}}
       }) do
    %{
      id: id,
      status: status,
      quality_control_name: name
    }
  end
end
