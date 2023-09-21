defmodule TdQx.DataViews.QueryableTest do
  use TdQx.DataCase

  import QueryableHelpers

  alias TdQx.DataViews.Queryable

  describe "Queryable changeset" do
    for type <- ~w|from join select where group_by| do
      @tag type: type
      test "test valid changeset for type #{type}", %{type: type} do
        params = %{
          id: 1,
          type: type,
          alias: "alias",
          properties: valid_properties_for(type)
        }

        assert %{valid?: true} = Queryable.changeset(%Queryable{}, params)
      end
    end

    test "test invalid type" do
      params = %{
        id: 1,
        type: "invalid",
        properties: %{}
      }

      assert %{valid?: false, errors: errors} = Queryable.changeset(%Queryable{}, params)

      assert [
               type: {"is invalid", [{:validation, :inclusion}, _]}
             ] = errors
    end

    test "test required fields" do
      params = %{}
      assert %{valid?: false, errors: errors} = Queryable.changeset(%Queryable{}, params)

      assert [
               {:id, {"can't be blank", [validation: :required]}},
               {:type, {"can't be blank", [validation: :required]}},
               {:properties, {"can't be blank", [validation: :required]}}
             ] = errors
    end
  end
end
