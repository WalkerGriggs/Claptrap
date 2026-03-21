defmodule Claptrap.Integration.CatalogProducerTest do
  use Claptrap.DataCase, async: false

  @moduletag :integration
  @moduletag capture_log: true

  alias Claptrap.Catalog
  alias Claptrap.Producer.{Router, Worker}
  alias Claptrap.Registry, as: Reg

  @source_attrs %{type: "rss", name: "Test Source", config: %{"url" => "https://example.com/feed"}}
  @sink_attrs %{type: "rss_feed", name: "Test Sink", config: %{"description" => "Test feed"}}

  defp create_source!(attrs \\ %{}) do
    {:ok, source} = Catalog.create_source(Map.merge(@source_attrs, attrs))
    source
  end

  defp create_sink!(attrs \\ %{}) do
    {:ok, sink} = Catalog.create_sink(Map.merge(@sink_attrs, attrs))
    sink
  end

  defp create_subscription!(sink, tags) do
    {:ok, sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: tags})
    sub
  end

  defp create_entry!(source, overrides) do
    attrs =
      Map.merge(
        %{
          source_id: source.id,
          external_id: "ext-#{System.unique_integer([:positive])}",
          title: "Test Entry",
          status: "unread",
          tags: []
        },
        overrides
      )

    {:ok, entry} = Catalog.create_entry(attrs)
    entry
  end

  setup do
    Supervisor.terminate_child(Claptrap.Supervisor, Claptrap.Producer.Supervisor)
    Process.sleep(20)

    try do
      :ets.new(:claptrap_rss_feeds, [:named_table, :public, :set, read_concurrency: true])
    rescue
      ArgumentError -> :ok
    end

    start_supervised!({DynamicSupervisor, strategy: :one_for_one, name: Claptrap.Producer.WorkerSupervisor})

    on_exit(fn ->
      try do
        :ets.delete_all_objects(:claptrap_rss_feeds)
      rescue
        ArgumentError -> :ok
      end

      ExUnit.CaptureLog.capture_log(fn ->
        Supervisor.restart_child(Claptrap.Supervisor, Claptrap.Producer.Supervisor)
      end)
    end)

    :ok
  end

  describe "subscriptions_for_tags returns matching subscriptions" do
    test "returns only subscriptions whose tags overlap with the query" do
      sink = create_sink!()
      match = create_subscription!(sink, ["elixir", "otp"])
      _no_match = create_subscription!(sink, ["rust"])

      assert [%{tags: ["elixir", "otp"], sink_id: sink_id}] = Catalog.subscriptions_for_tags(["elixir"])
      assert sink_id == match.sink_id
    end

    test "returns subscriptions from multiple sinks" do
      s1 = create_sink!(%{name: "Sink A"})
      s2 = create_sink!(%{name: "Sink B"})
      create_subscription!(s1, ["elixir"])
      create_subscription!(s2, ["elixir"])

      results = Catalog.subscriptions_for_tags(["elixir"])
      sink_ids = MapSet.new(results, & &1.sink_id)

      assert MapSet.equal?(sink_ids, MapSet.new([s1.id, s2.id]))
    end
  end

  describe "subscriptions_for_tags ANY-match semantics" do
    test "matches when any single tag overlaps" do
      sink = create_sink!()
      create_subscription!(sink, ["elixir", "otp"])

      assert [%{tags: ["elixir", "otp"]}] = Catalog.subscriptions_for_tags(["otp", "unrelated"])
    end

    test "does not require all subscription tags to overlap" do
      sink = create_sink!()
      create_subscription!(sink, ["elixir", "otp", "genserver"])

      assert [_] = Catalog.subscriptions_for_tags(["elixir"])
    end

    test "no match when tags are completely disjoint" do
      sink = create_sink!()
      create_subscription!(sink, ["elixir"])

      assert [] = Catalog.subscriptions_for_tags(["python"])
    end
  end

  describe "entries_for_sink tag overlap query" do
    test "returns entries whose tags overlap with the sink's subscription tags" do
      source = create_source!()
      sink = create_sink!()
      create_subscription!(sink, ["tech"])

      matching = create_entry!(source, %{tags: ["tech", "news"], title: "Match"})
      _non_matching = create_entry!(source, %{tags: ["sports"], title: "No Match"})

      assert [%{id: id, title: "Match"}] = Catalog.entries_for_sink(sink.id)
      assert id == matching.id
    end

    test "returns entries matching across multiple subscriptions" do
      source = create_source!()
      sink = create_sink!()
      create_subscription!(sink, ["elixir"])
      create_subscription!(sink, ["rust"])

      e1 = create_entry!(source, %{tags: ["elixir"], title: "Elixir Post"})
      e2 = create_entry!(source, %{tags: ["rust"], title: "Rust Post"})
      _e3 = create_entry!(source, %{tags: ["python"], title: "Python Post"})

      result_ids = Catalog.entries_for_sink(sink.id) |> MapSet.new(& &1.id)

      assert MapSet.equal?(result_ids, MapSet.new([e1.id, e2.id]))
    end
  end

  describe "entries_for_sink deduplication" do
    test "entry matched by multiple subscriptions on the same sink appears once" do
      source = create_source!()
      sink = create_sink!()
      create_subscription!(sink, ["elixir"])
      create_subscription!(sink, ["otp"])

      entry = create_entry!(source, %{tags: ["elixir", "otp"], title: "Both Tags"})

      assert [%{id: id, title: "Both Tags"}] = Catalog.entries_for_sink(sink.id)
      assert id == entry.id
    end
  end

  describe "entries_for_sink ordering" do
    test "returns entries ordered by inserted_at descending" do
      source = create_source!()
      sink = create_sink!()
      create_subscription!(sink, ["tech"])

      _old = create_entry!(source, %{tags: ["tech"], title: "Old"})
      Process.sleep(10)
      _new = create_entry!(source, %{tags: ["tech"], title: "New"})

      assert [%{title: "New"}, %{title: "Old"}] = Catalog.entries_for_sink(sink.id)
    end
  end

  describe "entries_for_sink respects limit" do
    test "returns at most N entries when limit is specified" do
      source = create_source!()
      sink = create_sink!()
      create_subscription!(sink, ["tech"])

      for i <- 1..10, do: create_entry!(source, %{tags: ["tech"], title: "Entry #{i}"})

      assert length(Catalog.entries_for_sink(sink.id, limit: 3)) == 3
    end

    test "returns all when fewer entries exist than the default limit" do
      source = create_source!()
      sink = create_sink!()
      create_subscription!(sink, ["tech"])

      for i <- 1..5, do: create_entry!(source, %{tags: ["tech"], title: "Entry #{i}"})

      assert length(Catalog.entries_for_sink(sink.id)) == 5
    end
  end

  describe "multi-sink fan-out via subscriptions" do
    test "one entry appears in entries_for_sink for each matching sink" do
      source = create_source!()
      sink1 = create_sink!(%{name: "Sink One"})
      sink2 = create_sink!(%{name: "Sink Two"})
      create_subscription!(sink1, ["elixir"])
      create_subscription!(sink2, ["elixir"])

      entry = create_entry!(source, %{tags: ["elixir"], title: "Shared Post"})

      assert [%{id: id1}] = Catalog.entries_for_sink(sink1.id)
      assert [%{id: id2}] = Catalog.entries_for_sink(sink2.id)
      assert id1 == entry.id
      assert id2 == entry.id
    end

    test "each sink only gets entries that match its own subscriptions" do
      source = create_source!()
      sink1 = create_sink!(%{name: "Elixir Sink"})
      sink2 = create_sink!(%{name: "Rust Sink"})
      create_subscription!(sink1, ["elixir"])
      create_subscription!(sink2, ["rust"])

      elixir_entry = create_entry!(source, %{tags: ["elixir"], title: "Elixir Post"})
      rust_entry = create_entry!(source, %{tags: ["rust"], title: "Rust Post"})

      assert [%{id: id1}] = Catalog.entries_for_sink(sink1.id)
      assert [%{id: id2}] = Catalog.entries_for_sink(sink2.id)
      assert id1 == elixir_entry.id
      assert id2 == rust_entry.id
    end
  end

  describe "unmatched tags produce empty results" do
    test "subscriptions_for_tags returns [] when no tags overlap" do
      sink = create_sink!()
      create_subscription!(sink, ["rust"])

      assert [] = Catalog.subscriptions_for_tags(["python"])
    end

    test "entries_for_sink returns [] when no entries match" do
      source = create_source!()
      sink = create_sink!()
      create_subscription!(sink, ["rust"])
      create_entry!(source, %{tags: ["python"], title: "Python Post"})

      assert [] = Catalog.entries_for_sink(sink.id)
    end

    test "entries with empty tags never match any subscription" do
      source = create_source!()
      sink = create_sink!()
      create_subscription!(sink, ["elixir"])
      create_entry!(source, %{tags: [], title: "Tagless Post"})

      assert [] = Catalog.entries_for_sink(sink.id)
    end
  end

  describe "sink deletion cascades to subscriptions" do
    test "deleting a sink removes its subscriptions from routing" do
      sink = create_sink!()
      create_subscription!(sink, ["elixir"])

      assert [_] = Catalog.subscriptions_for_tags(["elixir"])
      {:ok, _} = Catalog.delete_sink(sink)
      assert [] = Catalog.subscriptions_for_tags(["elixir"])
    end

    test "deleting one sink does not affect another sink's subscriptions" do
      s1 = create_sink!(%{name: "Sink A"})
      s2 = create_sink!(%{name: "Sink B"})
      create_subscription!(s1, ["elixir"])
      create_subscription!(s2, ["elixir"])

      {:ok, _} = Catalog.delete_sink(s1)

      assert [%{sink_id: remaining_sink_id}] = Catalog.subscriptions_for_tags(["elixir"])
      assert remaining_sink_id == s2.id
    end
  end

  describe "tag flow: source tags -> entry tags -> subscription match" do
    test "source tags inherited onto entries match subscriptions" do
      source = create_source!(%{tags: ["tech"]})
      sink = create_sink!()
      create_subscription!(sink, ["tech"])

      entry = create_entry!(source, %{tags: source.tags, title: "Inherited Match"})

      assert [%{id: id}] = Catalog.entries_for_sink(sink.id)
      assert id == entry.id
    end

    test "adapter tags combined with source tags expand match surface" do
      source = create_source!(%{tags: ["tech"]})
      sink_tech = create_sink!(%{name: "Tech Sink"})
      sink_elixir = create_sink!(%{name: "Elixir Sink"})
      create_subscription!(sink_tech, ["tech"])
      create_subscription!(sink_elixir, ["elixir"])

      merged_tags = Enum.uniq(source.tags ++ ["elixir"])
      entry = create_entry!(source, %{tags: merged_tags, title: "Tech + Elixir"})

      assert [%{id: id1}] = Catalog.entries_for_sink(sink_tech.id)
      assert [%{id: id2}] = Catalog.entries_for_sink(sink_elixir.id)
      assert id1 == entry.id
      assert id2 == entry.id
    end
  end

  describe "Router queries Catalog and dispatches to correct workers" do
    test "entries_ingested event routes to matching sink worker" do
      source = create_source!()
      sink = create_sink!()
      create_subscription!(sink, ["elixir"])

      start_supervised!({Worker, sink.id})
      start_supervised!(Router)

      entry = create_entry!(source, %{tags: ["elixir"], title: "Routed Post", url: "https://example.com/1"})

      send(Process.whereis(Router), {:entries_ingested, source.id, [entry]})
      _ = :sys.get_state(Process.whereis(Router))
      _ = :sys.get_state(Reg.whereis(:sink_worker, sink.id))

      [{_, {xml, _}}] = :ets.lookup(:claptrap_rss_feeds, sink.id)
      assert xml =~ "Routed Post"
    end

    test "entries with non-overlapping tags are not routed" do
      source = create_source!()
      sink = create_sink!()
      create_subscription!(sink, ["rust"])

      start_supervised!({Worker, sink.id})
      start_supervised!(Router)

      entry = create_entry!(source, %{tags: ["python"], title: "Unrouted Post"})

      send(Process.whereis(Router), {:entries_ingested, source.id, [entry]})
      _ = :sys.get_state(Process.whereis(Router))
      _ = :sys.get_state(Reg.whereis(:sink_worker, sink.id))

      case :ets.lookup(:claptrap_rss_feeds, sink.id) do
        [{_, {xml, _}}] -> refute xml =~ "Unrouted Post"
        [] -> :ok
      end
    end

    test "multi-sink fan-out: one event routes to multiple workers" do
      source = create_source!()
      sink1 = create_sink!(%{name: "Sink A"})
      sink2 = create_sink!(%{name: "Sink B"})
      create_subscription!(sink1, ["elixir"])
      create_subscription!(sink2, ["elixir"])

      start_supervised!({Worker, sink1.id}, id: :w1)
      start_supervised!({Worker, sink2.id}, id: :w2)
      start_supervised!(Router)

      entry = create_entry!(source, %{tags: ["elixir"], title: "Fan-out Post", url: "https://example.com/1"})

      send(Process.whereis(Router), {:entries_ingested, source.id, [entry]})
      _ = :sys.get_state(Process.whereis(Router))
      _ = :sys.get_state(Reg.whereis(:sink_worker, sink1.id))
      _ = :sys.get_state(Reg.whereis(:sink_worker, sink2.id))

      [{_, {xml1, _}}] = :ets.lookup(:claptrap_rss_feeds, sink1.id)
      [{_, {xml2, _}}] = :ets.lookup(:claptrap_rss_feeds, sink2.id)
      assert xml1 =~ "Fan-out Post"
      assert xml2 =~ "Fan-out Post"
    end

    test "empty tags on entries skip routing entirely" do
      source = create_source!()
      sink = create_sink!()
      create_subscription!(sink, ["elixir"])

      start_supervised!({Worker, sink.id})
      start_supervised!(Router)

      entry = create_entry!(source, %{tags: [], title: "Tagless"})

      send(Process.whereis(Router), {:entries_ingested, source.id, [entry]})
      _ = :sys.get_state(Process.whereis(Router))
      _ = :sys.get_state(Reg.whereis(:sink_worker, sink.id))

      case :ets.lookup(:claptrap_rss_feeds, sink.id) do
        [{_, {xml, _}}] -> refute xml =~ "Tagless"
        [] -> :ok
      end
    end
  end

  describe "Producer Worker loads sink config from Catalog on init" do
    test "starts successfully for a known sink type" do
      sink = create_sink!()
      pid = start_supervised!({Worker, sink.id})

      assert is_pid(pid)
      assert Reg.whereis(:sink_worker, sink.id) == pid

      assert %{sink: %{id: sink_id}, adapter: Claptrap.Producer.Adapters.RssFeed} = :sys.get_state(pid)
      assert sink_id == sink.id
    end

    test "fails to start for an unknown sink type" do
      {:ok, sink} = Catalog.create_sink(%{type: "unknown", name: "Bad Sink", config: %{}})

      assert {:error, _} = start_supervised({Worker, sink.id})
    end

    test "uses sink config for materialization" do
      source = create_source!()
      sink = create_sink!(%{config: %{"description" => "Custom Desc", "max_entries" => 2}})
      create_subscription!(sink, ["tech"])

      for i <- 1..5, do: create_entry!(source, %{tags: ["tech"], title: "Entry #{i}"})

      _pid = start_supervised!({Worker, sink.id})

      [{_, {xml, _}}] = :ets.lookup(:claptrap_rss_feeds, sink.id)
      assert xml =~ "Custom Desc"
      assert length(String.split(xml, "<item>")) - 1 == 2
    end

    test "seeds ETS on init with existing matching entries" do
      source = create_source!()
      sink = create_sink!()
      create_subscription!(sink, ["elixir"])
      create_entry!(source, %{tags: ["elixir"], title: "Pre-existing Entry"})

      _pid = start_supervised!({Worker, sink.id})

      [{_, {xml, _}}] = :ets.lookup(:claptrap_rss_feeds, sink.id)
      assert xml =~ "Pre-existing Entry"
    end
  end
end
