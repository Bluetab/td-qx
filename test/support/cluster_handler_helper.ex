defmodule ClusterHandlerHelper do
  @moduledoc """
    Function to inject a ClusterHandler response
  """
  import Mox

  def cluster_handler_expect(function, expected, times \\ 1),
    do: expect(MockClusterHandler, function, times, fn _, _, _, _ -> expected end)
end
