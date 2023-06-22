defmodule TdQx.DataSetsTest do
  use TdQx.DataCase

  alias TdQx.DataSets

  describe "data_sets" do
    alias TdQx.DataSets.DataSet

    @invalid_attrs %{name: nil, data_structure_id: nil}

    test "list_data_sets/0 returns all data_sets" do
      data_structures = Enum.map(1..3, fn _ -> build(:data_structure) end)

      datasets =
        data_structures
        |> Enum.map(&insert(:data_set, data_structure_id: &1.id, data_structure: &1))

      cluster_handler_expect({:ok, data_structures})

      assert DataSets.list_data_sets(enrich: [:data_structure]) == datasets
    end

    test "get_data_set!/1 returns the data_set with given id" do
      %{id: ds_id} = data_structure = build(:data_structure)
      data_set = insert(:data_set, data_structure_id: ds_id, data_structure: data_structure)

      cluster_handler_expect({:ok, data_structure})
      assert DataSets.get_data_set!(data_set.id, enrich: [:data_structure]) == data_set
    end

    test "create_data_set/1 with valid data creates a data_set" do
      %{id: ds_id} = data_structure = build(:data_structure)
      valid_attrs = %{name: "foo", data_structure_id: ds_id}

      cluster_handler_expect({:ok, data_structure})

      assert {:ok, %DataSet{} = data_set} =
               DataSets.create_data_set(valid_attrs, enrich: [:data_structure])

      assert data_set.name == "foo"
      assert data_set.data_structure_id == ds_id
      assert data_set.data_structure == data_structure
    end

    test "create_data_set/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               DataSets.create_data_set(@invalid_attrs, enrich: [:data_structure])
    end

    test "update_data_set/2 with valid data updates the data_set" do
      %{id: ds_id1} = data_structure1 = build(:data_structure)
      %{id: ds_id2} = data_structure2 = build(:data_structure)
      data_set = insert(:data_set, data_structure_id: ds_id1, data_structure: data_structure1)

      update_attrs = %{name: "foo", data_structure_id: ds_id2}

      cluster_handler_expect({:ok, data_structure2})

      assert {:ok, %DataSet{} = data_set} =
               DataSets.update_data_set(data_set, update_attrs, enrich: [:data_structure])

      assert data_set.name == "foo"
      assert data_set.data_structure_id == ds_id2
      assert data_set.data_structure == data_structure2
    end

    test "update_data_set/2 with invalid data returns error changeset" do
      %{id: ds_id} = data_structure = build(:data_structure)
      data_set = insert(:data_set, data_structure_id: ds_id, data_structure: data_structure)

      assert {:error, %Ecto.Changeset{}} =
               DataSets.update_data_set(data_set, @invalid_attrs, enrich: [:data_structure])

      cluster_handler_expect({:ok, data_structure})

      assert data_set == DataSets.get_data_set!(data_set.id, enrich: [:data_structure])
    end

    test "delete_data_set/1 deletes the data_set" do
      data_set = insert(:data_set)
      assert {:ok, %DataSet{}} = DataSets.delete_data_set(data_set)
      assert_raise Ecto.NoResultsError, fn -> DataSets.get_data_set!(data_set.id) end
    end

    test "change_data_set/1 returns a data_set changeset" do
      data_set = insert(:data_set)
      assert %Ecto.Changeset{} = DataSets.change_data_set(data_set)
    end
  end

  defp cluster_handler_expect(expected, times \\ 1),
    do: expect(MockClusterHandler, :call!, times, fn _, _, _, _ -> expected end)
end
