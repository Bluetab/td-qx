defmodule TdQx.CacheConfigTest do
  use ExUnit.Case

  setup do
    original_audit_config = Application.get_env(:td_cache, :audit, [])
    original_event_stream_config = Application.get_env(:td_cache, :event_stream, [])

    on_exit(fn ->
      Application.put_env(:td_cache, :audit, original_audit_config)
      Application.put_env(:td_cache, :event_stream, original_event_stream_config)
    end)

    :ok
  end

  describe "td-cache configuration from environment variables" do
    test "reads REDIS_AUDIT_STREAM_MAXLEN from environment" do
      System.put_env("REDIS_AUDIT_STREAM_MAXLEN", "170")

      Application.put_env(:td_cache, :audit,
        service: "td_qx",
        stream: "audit:events",
        maxlen: System.get_env("REDIS_AUDIT_STREAM_MAXLEN", "100")
      )

      audit_config = Application.get_env(:td_cache, :audit)
      assert Keyword.get(audit_config, :maxlen) == "170"

      System.delete_env("REDIS_AUDIT_STREAM_MAXLEN")
    end

    test "reads REDIS_STREAM_MAXLEN from environment" do
      System.put_env("REDIS_STREAM_MAXLEN", "260")

      Application.put_env(:td_cache, :event_stream,
        consumer_id: "default",
        consumer_group: "qx",
        maxlen: System.get_env("REDIS_STREAM_MAXLEN", "100"),
        streams: []
      )

      event_stream_config = Application.get_env(:td_cache, :event_stream)
      assert Keyword.get(event_stream_config, :maxlen) == "260"

      System.delete_env("REDIS_STREAM_MAXLEN")
    end

    test "uses default values when environment variables are not set" do
      System.delete_env("REDIS_AUDIT_STREAM_MAXLEN")
      System.delete_env("REDIS_STREAM_MAXLEN")

      Application.put_env(:td_cache, :audit,
        service: "td_qx",
        stream: "audit:events",
        maxlen: System.get_env("REDIS_AUDIT_STREAM_MAXLEN", "100")
      )

      Application.put_env(:td_cache, :event_stream,
        maxlen: System.get_env("REDIS_STREAM_MAXLEN", "100"),
        streams: []
      )

      audit_config = Application.get_env(:td_cache, :audit)
      event_stream_config = Application.get_env(:td_cache, :event_stream)

      assert Keyword.get(audit_config, :maxlen) == "100"
      assert Keyword.get(event_stream_config, :maxlen) == "100"
    end

    test "configuration preserves query execution streams" do
      System.put_env("REDIS_STREAM_MAXLEN", "340")

      Application.put_env(:td_cache, :event_stream,
        consumer_id: "default",
        consumer_group: "qx",
        maxlen: System.get_env("REDIS_STREAM_MAXLEN", "100"),
        streams: [
          [key: "query_execution:events", consumer: TdQx.Cache.QueryExecutor],
          [key: "result_cache:events", consumer: TdQx.Cache.ResultCache]
        ]
      )

      event_stream_config = Application.get_env(:td_cache, :event_stream)

      assert Keyword.get(event_stream_config, :maxlen) == "340"
      assert Keyword.get(event_stream_config, :consumer_group) == "qx"

      streams = Keyword.get(event_stream_config, :streams)
      assert length(streams) == 2

      query_stream = Enum.find(streams, &(Keyword.get(&1, :key) == "query_execution:events"))
      assert Keyword.get(query_stream, :consumer) == TdQx.Cache.QueryExecutor

      System.delete_env("REDIS_STREAM_MAXLEN")
    end
  end
end
