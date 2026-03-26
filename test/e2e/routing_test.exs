defmodule Claptrap.E2E.RoutingTest do
  use Claptrap.E2E.Case, async: false

  @source_params %{
    "type" => "rss",
    "name" => "Routing Test Source",
    "config" => %{"url" => "https://example.com/feed"}
  }

  @sink_params %{
    "type" => "rss",
    "name" => "Routing Test Sink",
    "config" => %{
      "description" => "Test feed",
      "link" => "https://example.com/routing-test-feed"
    }
  }

  defp create_source(ctx, opts \\ []) do
    tags = Keyword.get(opts, :tags, [])
    name = Keyword.get(opts, :name, @source_params["name"])
    params = %{@source_params | "name" => name} |> Map.put("tags", tags)
    {201, source} = http_post("/api/v1/sources", params)
    track_cleanup(ctx, "/api/v1/sources/#{source["id"]}")
    source
  end

  defp create_sink(ctx, opts \\ []) do
    name = Keyword.get(opts, :name, @sink_params["name"])
    params = %{@sink_params | "name" => name}
    {201, sink} = http_post("/api/v1/sinks", params)
    track_cleanup(ctx, "/api/v1/sinks/#{sink["id"]}")
    sink
  end

  defp create_subscription(ctx, sink_id, tags) do
    params = %{"sink_id" => sink_id, "tags" => tags}
    {201, subscription} = http_post("/api/v1/subscriptions", params)
    track_cleanup(ctx, "/api/v1/subscriptions/#{subscription["id"]}")
    subscription
  end

  defp create_entry(ctx, source_id, opts) do
    tags = Keyword.get(opts, :tags, [])
    title = Keyword.get(opts, :title, "Test Entry")
    external_id = Keyword.get(opts, :external_id, "ext-#{System.unique_integer([:positive])}")

    params = %{
      "source_id" => source_id,
      "external_id" => external_id,
      "title" => title,
      "status" => "unread",
      "tags" => tags
    }

    {201, entry} = http_post("/api/v1/entries", params)
    # Entries are cleaned up via source deletion (cascade)
    _ = ctx
    entry
  end

  describe "full routing flow" do
    test "entry with matching tags appears in entries list", ctx do
      source = create_source(ctx, tags: ["tech"])
      sink = create_sink(ctx)
      _subscription = create_subscription(ctx, sink["id"], ["tech"])
      entry = create_entry(ctx, source["id"], tags: ["tech"], title: "Tech Article")

      {200, body} = http_get("/api/v1/entries")
      ids = Enum.map(body["items"], & &1["id"])

      assert entry["id"] in ids
      assert entry["tags"] == ["tech"]
    end
  end

  describe "multi-sink fan-out" do
    test "entry with shared tag is visible when both sinks subscribe", ctx do
      source = create_source(ctx)
      sink_a = create_sink(ctx, name: "Sink A")
      sink_b = create_sink(ctx, name: "Sink B")
      _sub_a = create_subscription(ctx, sink_a["id"], ["elixir"])
      _sub_b = create_subscription(ctx, sink_b["id"], ["elixir"])

      entry = create_entry(ctx, source["id"], tags: ["elixir"], title: "Elixir Article")

      {200, body} = http_get("/api/v1/entries")
      ids = Enum.map(body["items"], & &1["id"])

      assert entry["id"] in ids
      assert entry["tags"] == ["elixir"]

      {200, subs_body} = http_get("/api/v1/subscriptions")

      matching =
        Enum.filter(subs_body["items"], fn sub ->
          Enum.any?(sub["tags"], &(&1 in entry["tags"]))
        end)

      sink_ids = Enum.map(matching, & &1["sink_id"]) |> Enum.sort()
      assert sink_a["id"] in sink_ids
      assert sink_b["id"] in sink_ids
    end
  end

  describe "tag isolation" do
    test "entry with non-matching tags does not match subscription", ctx do
      source = create_source(ctx)
      sink = create_sink(ctx)
      subscription = create_subscription(ctx, sink["id"], ["rust"])

      entry = create_entry(ctx, source["id"], tags: ["python"], title: "Python Article")

      {200, body} = http_get("/api/v1/entries")
      ids = Enum.map(body["items"], & &1["id"])
      assert entry["id"] in ids

      refute Enum.any?(subscription["tags"], &(&1 in entry["tags"]))
    end
  end

  describe "empty tags" do
    test "entry with empty tags does not match subscription", ctx do
      source = create_source(ctx)
      sink = create_sink(ctx)
      subscription = create_subscription(ctx, sink["id"], ["elixir"])

      entry = create_entry(ctx, source["id"], tags: [], title: "Untagged Entry")

      {200, body} = http_get("/api/v1/entries")
      ids = Enum.map(body["items"], & &1["id"])
      assert entry["id"] in ids

      assert entry["tags"] == []
      refute Enum.any?(subscription["tags"], &(&1 in entry["tags"]))
    end
  end

  describe "multiple subscriptions expand match surface" do
    test "sink with two subscriptions matches entries for either tag set", ctx do
      source = create_source(ctx)
      sink = create_sink(ctx)
      _sub_elixir = create_subscription(ctx, sink["id"], ["elixir"])
      _sub_otp = create_subscription(ctx, sink["id"], ["otp"])

      entry_elixir =
        create_entry(ctx, source["id"],
          tags: ["elixir"],
          title: "Elixir Entry"
        )

      entry_otp =
        create_entry(ctx, source["id"],
          tags: ["otp"],
          title: "OTP Entry"
        )

      entry_python =
        create_entry(ctx, source["id"],
          tags: ["python"],
          title: "Python Entry"
        )

      {200, subs_body} = http_get("/api/v1/subscriptions")

      sub_tags =
        subs_body["items"]
        |> Enum.filter(&(&1["sink_id"] == sink["id"]))
        |> Enum.flat_map(& &1["tags"])
        |> Enum.uniq()

      assert "elixir" in sub_tags
      assert "otp" in sub_tags

      assert Enum.any?(entry_elixir["tags"], &(&1 in sub_tags))
      assert Enum.any?(entry_otp["tags"], &(&1 in sub_tags))
      refute Enum.any?(entry_python["tags"], &(&1 in sub_tags))
    end
  end
end
