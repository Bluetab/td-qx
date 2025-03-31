defmodule TdQx.Search.Indexer do
  @moduledoc """
  Indexer for Quality Controls.
  """

  alias TdCore.Search.IndexWorker

  @index :quality_control_versions

  def reindex(ids, index \\ @index) do
    IndexWorker.reindex(index, ids)
  end

  def delete(ids, index \\ @index) do
    IndexWorker.delete(index, ids)
  end
end
