defmodule TdQx.Factory do
  @moduledoc """
  An `ExMachina` factory for data quality tests.
  """

  use ExMachina.Ecto, repo: TdQx.Repo

  alias TdQx.DataSets.DataSet

  def data_set_factory(attrs) do
    data_structure_id = sequence(:data_structure_id, & &1)

    %DataSet{
      name: sequence(:dataset_name, &"DataSet #{&1})"),
      data_structure_id: data_structure_id,
      data_structure: build(:data_structure, data_structure_id: data_structure_id)
    }
    |> merge_attributes(attrs)
  end

  def data_structure_factory(attrs) do
    %{
      id: sequence(:id, & &1),
      system_id: sequence(:system_id, & &1),
      external_id: sequence(:data_structure_external_id, &"external_id_#{&1})")
    }
    |> merge_attributes(attrs)
  end
end
