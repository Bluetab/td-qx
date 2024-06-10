defmodule TdQx.Search.Indexer do
  @moduledoc """
  Indexer for Quality Controls.
  """

  alias TdCore.Search.IndexWorker

  @index :quality_controls

  def reindex(ids) do
    IndexWorker.reindex(@index, ids)
  end

  def delete(ids) do
    IndexWorker.delete(@index, ids)
  end
end
