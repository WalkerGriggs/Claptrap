defmodule Claptrap.Producer.Adapters.RssFeedTest do
  use Claptrap.DataCase, async: false
  use ExUnitProperties

  @moduletag :integration
  @moduletag capture_log: true

  alias Claptrap.Catalog
  alias Claptrap.Catalog.Sink
  alias Claptrap.Producer.Adapters.RssFeed

  @source_attrs %{type: "rss", name: "Source", config: %{"url" => "https://example.com/feed"}}
  @sink_attrs %{
    type: "rss",
    name: "My Feed",
    config: %{"description" => "A test feed", "link" => "https://example.com/my-feed"}
  }

  setup do
    Supervisor.terminate_child(Claptrap.Supervisor, Claptrap.Producer.Supervisor)
    Process.sleep(20)

    try do
      :ets.new(:claptrap_rss_feeds, [:named_table, :public, :set, read_concurrency: true])
    rescue
      ArgumentError -> :ok
    end

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

  describe "mode/0" do
    test "returns :pull" do
      assert RssFeed.mode() == :pull
    end
  end

  describe "push/2" do
    test "returns error not_supported" do
      sink = %Sink{id: Ecto.UUID.generate(), name: "Test", config: %{}}
      assert {:error, :not_supported} = RssFeed.push(sink, [])
    end
  end

  describe "validate_config/1" do
    test "accepts valid config with description and link" do
      assert :ok =
               RssFeed.validate_config(%{
                 "description" => "A feed",
                 "link" => "https://example.com/feed"
               })
    end

    test "accepts config with description, link, and max_entries" do
      assert :ok =
               RssFeed.validate_config(%{
                 "description" => "A feed",
                 "link" => "https://example.com/feed",
                 "max_entries" => 25
               })
    end

    test "rejects config without link" do
      assert {:error, "missing required key: link"} =
               RssFeed.validate_config(%{"description" => "A feed", "max_entries" => 25})
    end

    test "rejects config without description" do
      assert {:error, "missing required key: description"} =
               RssFeed.validate_config(%{"link" => "https://example.com/feed", "max_entries" => 25})
    end

    test "rejects config without description and link" do
      assert {:error, "missing required keys: description, link"} =
               RssFeed.validate_config(%{"max_entries" => 25})
    end

    test "rejects config with non-integer max_entries" do
      assert {:error, "max_entries must be a positive integer"} =
               RssFeed.validate_config(%{
                 "description" => "A feed",
                 "link" => "https://example.com/feed",
                 "max_entries" => "fifty"
               })
    end

    test "rejects config with zero max_entries" do
      assert {:error, "max_entries must be a positive integer"} =
               RssFeed.validate_config(%{
                 "description" => "A feed",
                 "link" => "https://example.com/feed",
                 "max_entries" => 0
               })
    end

    test "rejects config with negative max_entries" do
      assert {:error, "max_entries must be a positive integer"} =
               RssFeed.validate_config(%{
                 "description" => "A feed",
                 "link" => "https://example.com/feed",
                 "max_entries" => -5
               })
    end

    test "rejects config with blank link" do
      assert {:error, "link must be a non-empty string"} =
               RssFeed.validate_config(%{"description" => "A feed", "link" => "   "})
    end

    test "rejects config with non-binary link" do
      assert {:error, "link must be a non-empty string"} =
               RssFeed.validate_config(%{"description" => "A feed", "link" => 123})
    end

    test "rejects config with invalid link" do
      assert {:error, "link must be an absolute URL with scheme and host"} =
               RssFeed.validate_config(%{"description" => "A feed", "link" => "example.com/feed"})
    end

    test "rejects config with scheme but missing host" do
      for link <- ["mailto:test@example.com", "https:///path-only"] do
        assert {:error, "link must be an absolute URL with scheme and host"} =
                 RssFeed.validate_config(%{"description" => "A feed", "link" => link})
      end
    end

    test "rejects non-map config" do
      assert {:error, "config must be a map"} = RssFeed.validate_config("bad")
    end

    property "accepts any positive integer max_entries with valid description and link" do
      check all(max_entries <- integer(1..1_000_000), max_runs: 50) do
        assert :ok =
                 RssFeed.validate_config(%{
                   "description" => "A feed",
                   "link" => "https://example.com/feed",
                   "max_entries" => max_entries
                 })
      end
    end

    property "rejects any non-positive integer max_entries" do
      check all(max_entries <- integer(-100_000..0), max_runs: 50) do
        assert {:error, "max_entries must be a positive integer"} =
                 RssFeed.validate_config(%{
                   "description" => "A feed",
                   "link" => "https://example.com/feed",
                   "max_entries" => max_entries
                 })
      end
    end

    property "rejects non-integer max_entries values" do
      check all(
              max_entries <-
                one_of([
                  float(min: -10_000.0, max: 10_000.0),
                  boolean(),
                  string(:alphanumeric, min_length: 1, max_length: 40),
                  list_of(integer(), max_length: 3),
                  map_of(
                    string(:alphanumeric, min_length: 1, max_length: 8),
                    integer(),
                    max_length: 2
                  )
                ]),
              max_runs: 50
            ) do
        assert {:error, "max_entries must be a positive integer"} =
                 RssFeed.validate_config(%{
                   "description" => "A feed",
                   "link" => "https://example.com/feed",
                   "max_entries" => max_entries
                 })
      end
    end
  end

  describe "materialize/2" do
    test "produces valid RSS 2.0 XML and stores in ETS" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      {:ok, _sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["elixir"]})

      {:ok, entry} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "ext-1",
          title: "Hello Elixir",
          url: "https://example.com/1",
          summary: "A post about Elixir",
          author: "Author One",
          published_at: ~U[2026-01-15 10:00:00.000000Z],
          status: "unread",
          tags: ["elixir"]
        })

      assert :ok = RssFeed.materialize(sink, [])

      assert {:ok, xml, _updated_at} = RssFeed.get_feed(sink.id)
      assert xml =~ ~r/<rss version="2.0">/
      assert xml =~ "<title>My Feed</title>"
      assert xml =~ "<link>https://example.com/my-feed</link>"
      assert xml =~ "<description>A test feed</description>"
      assert xml =~ "<title>Hello Elixir</title>"
      assert xml =~ "<link>https://example.com/1</link>"
      assert xml =~ "<description>A post about Elixir</description>"
      assert xml =~ "<author>Author One</author>"
      assert xml =~ "<guid isPermaLink=\"false\">#{entry.id}</guid>"
    end

    test "emits channel link exactly once" do
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      {:ok, _sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["none"]})

      assert :ok = RssFeed.materialize(sink, [])
      {:ok, xml, _updated_at} = RssFeed.get_feed(sink.id)

      channel_link = "<link>https://example.com/my-feed</link>"
      occurrences = xml |> String.split(channel_link) |> length() |> Kernel.-(1)
      assert occurrences == 1
    end

    test "trims surrounding whitespace in emitted channel link" do
      {:ok, sink} =
        Catalog.create_sink(%{
          type: "rss",
          name: "Whitespace Feed",
          config: %{
            "description" => "Feed with spaced link",
            "link" => "   https://example.com/spaced-link   "
          }
        })

      {:ok, _sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["none"]})

      assert :ok = RssFeed.materialize(sink, [])
      {:ok, xml, _updated_at} = RssFeed.get_feed(sink.id)

      assert xpath_text(xml, "/rss/channel/link") == "https://example.com/spaced-link"
    end

    property "channel link appears exactly once for any valid sink link and entry set" do
      check all(
              sink_slug <- string(:alphanumeric, min_length: 1, max_length: 20),
              entry_slugs <- list_of(string(:alphanumeric, min_length: 1, max_length: 20), max_length: 5),
              max_runs: 20
            ) do
        {:ok, source} = Catalog.create_source(@source_attrs)

        sink_link = "https://example.com/#{sink_slug}"

        {:ok, sink} =
          Catalog.create_sink(%{
            type: "rss",
            name: "Property Feed #{sink_slug}",
            config: %{
              "description" => "Property-based channel link test",
              "link" => sink_link
            }
          })

        {:ok, _sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["prop-tag"]})

        Enum.each(entry_slugs, fn entry_slug ->
          {:ok, _entry} =
            Catalog.create_entry(%{
              source_id: source.id,
              external_id: "prop-#{System.unique_integer([:positive])}-#{entry_slug}",
              title: "Entry #{entry_slug}",
              url: "https://entries.example/#{entry_slug}",
              status: "unread",
              tags: ["prop-tag"]
            })
        end)

        assert :ok = RssFeed.materialize(sink, [])
        {:ok, xml, _updated_at} = RssFeed.get_feed(sink.id)

        assert length(xpath(xml, "/rss/channel/link")) == 1
        assert xpath_text(xml, "/rss/channel/link") == sink_link
      end
    end

    test "XML contains entries in correct order (newest first)" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      {:ok, _sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["elixir"]})

      {:ok, _} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "old",
          title: "Old Post",
          status: "unread",
          tags: ["elixir"]
        })

      Process.sleep(10)

      {:ok, _} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "new",
          title: "New Post",
          status: "unread",
          tags: ["elixir"]
        })

      assert :ok = RssFeed.materialize(sink, [])
      {:ok, xml, _} = RssFeed.get_feed(sink.id)

      old_pos = :binary.match(xml, "Old Post") |> elem(0)
      new_pos = :binary.match(xml, "New Post") |> elem(0)
      assert new_pos < old_pos
    end

    test "handles entries with nil optional fields" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      {:ok, _sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["test"]})

      {:ok, _} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "minimal",
          title: "Minimal",
          status: "unread",
          tags: ["test"]
        })

      assert :ok = RssFeed.materialize(sink, [])
      {:ok, xml, _} = RssFeed.get_feed(sink.id)
      assert xml =~ "<title>Minimal</title>"
      assert xml =~ "<link></link>"
      assert xml =~ "<description></description>"
      assert xml =~ "<author></author>"
    end

    test "respects max_entries config" do
      {:ok, source} = Catalog.create_source(@source_attrs)

      {:ok, sink} =
        Catalog.create_sink(%{
          type: "rss",
          name: "Limited Feed",
          config: %{
            "description" => "Limited",
            "link" => "https://example.com/limited-feed",
            "max_entries" => 2
          }
        })

      {:ok, _sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["elixir"]})

      for i <- 1..5 do
        {:ok, _} =
          Catalog.create_entry(%{
            source_id: source.id,
            external_id: "e#{i}",
            title: "Entry #{i}",
            status: "unread",
            tags: ["elixir"]
          })
      end

      assert :ok = RssFeed.materialize(sink, [])
      {:ok, xml, _} = RssFeed.get_feed(sink.id)

      item_count = xml |> String.split("<item>") |> length() |> Kernel.-(1)
      assert item_count == 2
    end

    test "escapes special XML characters" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      {:ok, _sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["test"]})

      {:ok, _} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "special",
          title: "Foo & Bar <baz>",
          summary: "It's a \"test\"",
          status: "unread",
          tags: ["test"]
        })

      assert :ok = RssFeed.materialize(sink, [])
      {:ok, xml, _} = RssFeed.get_feed(sink.id)
      assert xml =~ "Foo &amp; Bar &lt;baz&gt;"
      assert xml =~ "It&apos;s a &quot;test&quot;"
    end

    test "produces a feed with zero items when no entries match" do
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      {:ok, _sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["elixir"]})

      assert :ok = RssFeed.materialize(sink, [])
      {:ok, xml, _} = RssFeed.get_feed(sink.id)

      assert xml =~ "<title>My Feed</title>"
      refute xml =~ "<item>"
    end

    test "re-materialization overwrites previous feed" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      {:ok, _sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["elixir"]})

      assert :ok = RssFeed.materialize(sink, [])
      {:ok, xml1, _} = RssFeed.get_feed(sink.id)
      refute xml1 =~ "<item>"

      {:ok, _} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "ext-1",
          title: "New Entry",
          status: "unread",
          tags: ["elixir"]
        })

      assert :ok = RssFeed.materialize(sink, [])
      {:ok, xml2, _} = RssFeed.get_feed(sink.id)
      assert xml2 =~ "New Entry"
    end
  end

  describe "get_feed/1" do
    test "returns :not_found when no feed exists" do
      assert {:error, :not_found} = RssFeed.get_feed(Ecto.UUID.generate())
    end
  end

  defp parse_xml(xml) do
    xml
    |> String.to_charlist()
    |> :xmerl_scan.string(quiet: true)
  end

  defp xpath(xml_string, path) do
    {doc, _} = parse_xml(xml_string)
    :xmerl_xpath.string(String.to_charlist(path), doc)
  end

  defp xpath_text(xml_string, path) do
    case xpath(xml_string, path) do
      [{:xmlElement, _, _, _, _, _, _, _, children, _, _, _} | _] ->
        Enum.map_join(children, "", fn
          {:xmlText, _, _, _, value, _} -> to_string(value)
          _ -> ""
        end)

      _ ->
        nil
    end
  end
end
