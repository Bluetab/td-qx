defmodule TdQx.Search.IndexerTest do
  use TdQx.DataCase

  alias TdCore.Search.IndexWorkerMock
  alias TdQx.Search.Indexer

  test "reindex/2 calls IndexWorker.reindex with default index" do
    IndexWorkerMock.clear()

    Indexer.reindex([1, 2, 3])

    assert IndexWorkerMock.calls() == [{:reindex, :quality_control_versions, [1, 2, 3]}]
  end

  test "reindex/2 calls IndexWorker.reindex with custom index" do
    IndexWorkerMock.clear()

    Indexer.reindex([1, 2], :custom_index)

    assert IndexWorkerMock.calls() == [{:reindex, :custom_index, [1, 2]}]
  end

  test "delete/2 calls IndexWorker.delete with default index" do
    IndexWorkerMock.clear()

    Indexer.delete([1, 2, 3])

    assert IndexWorkerMock.calls() == [{:delete, :quality_control_versions, [1, 2, 3]}]
  end

  test "delete/2 calls IndexWorker.delete with custom index" do
    IndexWorkerMock.clear()

    Indexer.delete([1], :custom_index)

    assert IndexWorkerMock.calls() == [{:delete, :custom_index, [1]}]
  end
end
