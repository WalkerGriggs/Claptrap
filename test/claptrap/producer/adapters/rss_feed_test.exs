defmodule Claptrap.Producer.Adapters.RssFeedTest do
  use Claptrap.DataCase, async: false

  alias Claptrap.Catalog
  alias Claptrap.Producer.Adapters.RssFeed

  @source_attrs %{type: "rss", name: "Feed", config: %{"url" => "https://example.com/feed"}}
  @sink_attrs %{
    type: "rss_feed",
    name: "My RSS Feed",
    config: %{"description" => "A combined feed"}
  }

  setup do
    if :ets.whereis(:claptrap_rss_feeds) == :undefined do
      :ets.new(:claptrap_rss_feeds, [:named_table, :public, :set, read_concurrency: true])
    end

    :ok
  end

  describe "mode/0" do
    test "returns :pull" do
      assert RssFeed.mode() == :pull
    end
  end

  describe "validate_config/1" do
    test "accepts valid config with description" do
      assert :ok = RssFeed.validate_config(%{"description" => "A feed"})
    end

    test "accepts config with description and max_entries" do
      assert :ok = RssFeed.validate_config(%{"description" => "Feed", "max_entries" => 25})
    end

    test "rejects config missing description" do
      assert {:error, msg} = RssFeed.validate_config(%{})
      assert msg =~ "description"
    end

    test "rejects config with empty description" do
      assert {:error, msg} = RssFeed.validate_config(%{"description" => ""})
      assert msg =~ "description"
    end

    test "rejects non-map config" do
      assert {:error, _} = RssFeed.validate_config("not a map")
    end
  end

  describe "materialize/2" do
    setup do
      {:ok, source} = Catalog.create_source(@source_attrs)
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      {:ok, _sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["elixir"]})
      %{source: source, sink: sink}
    end

    test "produces valid RSS 2.0 XML", %{source: source, sink: sink} do
      {:ok, _entry} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "e1",
          title: "Hello Elixir",
          url: "https://example.com/1",
          summary: "A summary",
          author: "Author",
          status: "unread",
          tags: ["elixir"]
        })

      assert :ok = RssFeed.materialize(sink, [])

      [{_sink_id, {xml, _updated_at}}] = :ets.lookup(:claptrap_rss_feeds, sink.id)
      assert xml =~ ~s(<?xml version="1.0" encoding="UTF-8"?>)
      assert xml =~ ~s(<rss version="2.0">)
      assert xml =~ "<title>My RSS Feed</title>"
      assert xml =~ "<description>A combined feed</description>"
      assert xml =~ "<title>Hello Elixir</title>"
      assert xml =~ "<link>https://example.com/1</link>"
      assert xml =~ "<description>A summary</description>"
      assert xml =~ "<author>Author</author>"
    end

    test "stores result in ETS with sink_id as key", %{sink: sink} do
      assert :ok = RssFeed.materialize(sink, [])

      result = :ets.lookup(:claptrap_rss_feeds, sink.id)
      assert [{sink_id, {xml, updated_at}}] = result
      assert sink_id == sink.id
      assert is_binary(xml)
      assert %DateTime{} = updated_at
    end

    test "entries appear in descending inserted_at order", %{source: source, sink: sink} do
      {:ok, e1} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "older",
          title: "Older Entry",
          status: "unread",
          tags: ["elixir"]
        })

      # Force distinct timestamps so ordering is
      # deterministic
      import Ecto.Query

      older_ts = ~U[2026-01-01 00:00:00.000000Z]
      newer_ts = ~U[2026-01-02 00:00:00.000000Z]

      from(e in "entries",
        where: e.id == type(^e1.id, :binary_id)
      )
      |> Claptrap.Repo.update_all(set: [inserted_at: older_ts])

      {:ok, e2} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "newer",
          title: "Newer Entry",
          status: "unread",
          tags: ["elixir"]
        })

      from(e in "entries",
        where: e.id == type(^e2.id, :binary_id)
      )
      |> Claptrap.Repo.update_all(set: [inserted_at: newer_ts])

      assert :ok = RssFeed.materialize(sink, [])

      [{_sink_id, {xml, _}}] = :ets.lookup(:claptrap_rss_feeds, sink.id)
      newer_pos = :binary.match(xml, "Newer Entry") |> elem(0)
      older_pos = :binary.match(xml, "Older Entry") |> elem(0)
      assert newer_pos < older_pos
    end

    test "handles entries with nil optional fields", %{source: source, sink: sink} do
      {:ok, _entry} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "minimal",
          title: "Minimal Entry",
          status: "unread",
          tags: ["elixir"]
        })

      assert :ok = RssFeed.materialize(sink, [])

      [{_sink_id, {xml, _}}] = :ets.lookup(:claptrap_rss_feeds, sink.id)
      assert xml =~ "<title>Minimal Entry</title>"
      assert xml =~ "<link></link>"
      assert xml =~ "<description></description>"
      assert xml =~ "<author></author>"
    end

    test "escapes special characters in title", %{source: source, sink: sink} do
      {:ok, _entry} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "special",
          title: "A <special> & \"tricky\" entry",
          status: "unread",
          tags: ["elixir"]
        })

      assert :ok = RssFeed.materialize(sink, [])

      [{_sink_id, {xml, _}}] = :ets.lookup(:claptrap_rss_feeds, sink.id)
      assert xml =~ "A &lt;special&gt; &amp; &quot;tricky&quot; entry"
    end
  end

  describe "push/2" do
    test "returns error" do
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      assert {:error, _} = RssFeed.push(sink, [])
    end
  end
end
