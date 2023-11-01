defmodule TdQxWeb.SearchJSON do
  @moduledoc """
  Provides JSON view for Search
  """

  @doc """
  Renders search results
  """
  def show(%{results: results}) do
    %{
      data: results
    }
  end
end
