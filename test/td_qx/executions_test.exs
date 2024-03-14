defmodule TdQx.ExecutionsTest do
  use TdQx.DataCase

  alias TdQx.Executions

  describe "execution_groups" do
    test "list_execution_groups/0 returns all execution_groups" do
      execution_groups = insert(:execution_groups)
      assert Executions.list_execution_groups() == [execution_groups]
    end

    test "get_execution_groups/1 returns the execution_groups with given id" do
      execution_group = create_execution_group(3)

      assert Executions.get_execution_group(execution_group.id) == execution_group
    end

    test "create_execution_group/1 with valid data creates a execution_groups" do
      valid_attrs = %{"df_content" => %{"scheduled" => "No"}}

      assert {:ok, %{id: execution_group_id}} =
               Enum.map(1..5, fn _id -> create_quality_control() end)
               |> Executions.create_execution_group(valid_attrs)

      %{executions: executions} = Executions.get_execution_group(execution_group_id)

      assert length(executions) == 5
    end

    test "create_execution_group/1 will not create executions of quality_controls that does not exist" do
      valid_attrs = %{"df_content" => %{"scheduled" => "No"}}

      assert {:ok, %{id: execution_group_id}} =
               1..5
               |> Enum.map(&Map.new(%{id: &1}))
               |> Executions.create_execution_group(valid_attrs)

      %{executions: executions} = Executions.get_execution_group(execution_group_id)

      assert Enum.empty?(executions)
    end

    test "create_execution_group/1 with invalid data returns error changeset" do
      invalid_attrs = %{"df_content" => nil}

      assert {:error, %Ecto.Changeset{errors: errors}} =
               1..5
               |> Enum.map(&Map.new(id: &1))
               |> Executions.create_execution_group(invalid_attrs)

      assert [df_content: {"can't be blank", [validation: :required]}] = errors
    end

    test "create_execution_group/1 fails with no quality_controls" do
      invalid_attrs = %{"df_content" => %{"foo" => "bar"}}

      assert {:error, :not_found} = Executions.create_execution_group([], invalid_attrs)
    end
  end

  describe "execution" do
    test "list_execution/0 returns all execution" do
      execution = insert(:execution)
      assert Executions.list_execution() == [execution]
    end

    test "get_execution!/1 returns the execution with given id" do
      execution = insert(:execution)
      assert Executions.get_execution!(execution.id) == execution
    end

    test "change_execution/1 returns a execution changeset" do
      execution = insert(:execution)
      assert %Ecto.Changeset{} = Executions.change_execution(execution)
    end
  end

  defp create_execution_group(max) do
    executions = create_execution(max)

    insert(:execution_groups, executions: executions)
  end

  defp create_execution(max) do
    %{id: eg_id} = insert(:execution_groups)

    Enum.map(1..max, fn _id ->
      %{id: quality_control_id} = quality_control = create_quality_control()

      insert(:execution, %{
        execution_group_id: eg_id,
        quality_control_id: quality_control_id,
        quality_control: quality_control
      })
    end)
  end

  defp create_quality_control do
    quality_control = insert(:quality_control)

    quality_control_version =
      insert(:quality_control_version,
        status: "published",
        quality_control: quality_control
      )

    Map.merge(quality_control, %{published_version: quality_control_version})
  end
end
