defmodule TdQx.HelpersTest do
  use ExUnit.Case

  alias TdQx.Helpers

  test "has_duplicates? returns true when list has duplicates" do
    assert Helpers.has_duplicates?([1, 2, 3, 2]) == true
  end

  test "has_duplicates? returns true when list has multiple duplicates" do
    assert Helpers.has_duplicates?([1, 2, 1, 2, 3]) == true
  end

  test "has_duplicates? returns false when list has no duplicates" do
    assert Helpers.has_duplicates?([1, 2, 3, 4]) == false
  end

  test "has_duplicates? returns false for empty list" do
    assert Helpers.has_duplicates?([]) == false
  end

  test "has_duplicates? returns true when all elements are duplicates" do
    assert Helpers.has_duplicates?([1, 1, 1]) == true
  end

  test "has_duplicates? works with string lists" do
    assert Helpers.has_duplicates?(["a", "b", "a"]) == true
  end

  test "has_duplicates? returns false for single element list" do
    assert Helpers.has_duplicates?([1]) == false
  end
end
