defmodule TdQx.DataSetsTest do
  use TdQx.DataCase

  import ExUnit.CaptureLog

  alias TdQx.DataSets

  describe "data_sets" do
    alias TdQx.DataSets.DataSet

    @invalid_attrs %{name: nil, data_structure_id: nil}

    test "list_data_sets/0 returns all data_sets enriched" do
      [%{id: ds_id_0} = ds0, %{id: ds_id_1} = ds1, %{id: ds_id_2} = ds2] =
        data_structures = Enum.map(1..3, fn _ -> build(:data_structure) end)

      [
        %{id: dset_id_0, name: dset_name_0},
        %{id: dset_id_1, name: dset_name_1},
        %{id: dset_id_2, name: dset_name_2}
      ] =
        data_sets =
        data_structures
        |> Enum.map(&insert(:data_set, data_structure_id: &1.id, data_structure: &1))

      cluster_handler_expect(:call, {:ok, data_structures})

      assert [
               %{
                 data_structure: ^ds0,
                 data_structure_id: ^ds_id_0,
                 id: ^dset_id_0,
                 name: ^dset_name_0
               },
               %{
                 data_structure: ^ds1,
                 data_structure_id: ^ds_id_1,
                 id: ^dset_id_1,
                 name: ^dset_name_1
               },
               %{
                 data_structure: ^ds2,
                 data_structure_id: ^ds_id_2,
                 id: ^dset_id_2,
                 name: ^dset_name_2
               }
             ] = DataSets.list_data_sets(enrich: true)
    end

    test "get_data_set!/1 returns the enriched data_set with given id" do
      %{id: ds_id} = data_structure = build(:data_structure)

      %{id: dset_id, name: dset_name} =
        insert(:data_set, data_structure_id: ds_id, data_structure: data_structure)

      cluster_handler_expect(:call, {:ok, data_structure})

      assert %{
               data_structure: ^data_structure,
               data_structure_id: ^ds_id,
               id: ^dset_id,
               name: ^dset_name
             } = DataSets.get_data_set!(dset_id, enrich: true)
    end

    test "get_data_set!/1 with enrich option will not fail if cluster isn't available" do
      %{id: ds_id} = data_structure = build(:data_structure)
      data_set = insert(:data_set, data_structure_id: ds_id, data_structure: data_structure)

      cluster_handler_expect(:call, {:error, nil})
      {result, log} = with_log(fn -> DataSets.get_data_set!(data_set.id, enrich: true) end)

      assert %{data_structure: nil} = result
      assert log =~ "[warning] Failed to enrich DataSet from cluster"
    end

    test "create_data_set/1 with valid data creates a data_set" do
      %{id: ds_id} = data_structure = build(:data_structure)
      valid_attrs = %{name: "foo", data_structure_id: ds_id}

      cluster_handler_expect(:call, {:ok, data_structure})

      assert {:ok, %DataSet{} = data_set} = DataSets.create_data_set(valid_attrs)

      assert data_set.name == "foo"
      assert data_set.data_structure_id == ds_id
      assert data_set.data_structure == data_structure
    end

    test "create_data_set/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = DataSets.create_data_set(@invalid_attrs)
    end

    test "update_data_set/2 with valid data updates the data_set" do
      %{id: ds_id1} = data_structure1 = build(:data_structure)
      %{id: ds_id2} = data_structure2 = build(:data_structure)
      data_set = insert(:data_set, data_structure_id: ds_id1, data_structure: data_structure1)

      update_attrs = %{name: "foo", data_structure_id: ds_id2}

      cluster_handler_expect(:call, {:ok, data_structure2})

      assert {:ok, %DataSet{} = data_set} = DataSets.update_data_set(data_set, update_attrs)

      assert data_set.name == "foo"
      assert data_set.data_structure_id == ds_id2
      assert data_set.data_structure == data_structure2
    end

    test "update_data_set/2 with invalid data returns error changeset" do
      %{id: ds_id} = data_structure = build(:data_structure)

      %{id: id, name: name} =
        data_set = insert(:data_set, data_structure_id: ds_id, data_structure: data_structure)

      assert {:error, %Ecto.Changeset{}} = DataSets.update_data_set(data_set, @invalid_attrs)

      cluster_handler_expect(:call, {:ok, data_structure})

      assert %{
               data_structure: ^data_structure,
               data_structure_id: ^ds_id,
               id: ^id,
               name: ^name
             } = DataSets.get_data_set!(id, enrich: true)
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
end
