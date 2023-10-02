defmodule TdQx.DataViews.ResourceTest do
  use TdQx.DataCase

  alias TdQx.DataViews.Resource

  describe "resource changeset" do
    test "test valid changeset" do
      for type <- ~w|data_structure reference_dataset data_view| do
        params = %{
          id: 1,
          type: type
        }

        assert %{valid?: true} = Resource.changeset(%Resource{}, params)
      end
    end

    test "test required fields" do
      params = %{}
      assert %{valid?: false, errors: errors} = Resource.changeset(%Resource{}, params)

      assert [
               {:id, {"can't be blank", [validation: :required]}},
               {:type, {"can't be blank", [validation: :required]}}
             ] = errors
    end
  end
end
