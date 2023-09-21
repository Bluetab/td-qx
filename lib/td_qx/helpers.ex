defmodule TdQx.Helpers do
  @moduledoc """
  Module for generic helper functions
  """
  def has_duplicates?(list), do: not Enum.empty?(list -- Enum.uniq(list))
end
