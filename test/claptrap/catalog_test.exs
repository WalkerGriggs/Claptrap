defmodule Claptrap.CatalogTest do
  use Claptrap.DataCase, async: true

  alias Claptrap.Catalog

  @source_attrs %{type: "rss", name: "Feed", config: %{"url" => "https://example.com/feed"}}
  @sink_attrs %{type: "webhook", name: "Hook", config: %{"url" => "https://example.com/hook"}}

  # Sources

  describe "create_source/1" do
    test "creates a source with valid attrs" do
      assert {:ok, source} = Catalog.create_source(@source_attrs)
      assert source.type == "rss"
      assert source.name == "Feed"
    end

    test "returns error with invalid attrs" do
      assert {:error, changeset} = Catalog.create_source(%{})
      assert %{type: _, name: _, config: _} = errors_on(changeset)
    end
  end

  describe "list_sources/1" do
    test "returns all sources" do
      {:ok, _} = Catalog.create_source(@source_attrs)
      assert [_] = Catalog.list_sources()
    end

    test "filters by enabled" do
      {:ok, _} = Catalog.create_source(@source_attrs)
      {:ok, _} = Catalog.create_source(Map.put(@source_attrs, :enabled, false))

      assert [s] = Catalog.list_sources(enabled: true)
      assert s.enabled
      assert [s2] = Catalog.list_sources(enabled: false)
      refute s2.enabled
    end
  end

  describe "get_source!/1" do
    test "returns the source" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      assert Catalog.get_source!(source.id).id == source.id
    end

    test "raises on not found" do
      assert_raise Ecto.NoResultsError, fn ->
        Catalog.get_source!(Ecto.UUID.generate())
      end
    end
  end

  describe "update_source/2" do
    test "updates the source" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      assert {:ok, updated} = Catalog.update_source(source, %{name: "Updated"})
      assert updated.name == "Updated"
    end
  end

  describe "delete_source/1" do
    test "deletes the source" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      assert {:ok, _} = Catalog.delete_source(source)
      assert Catalog.list_sources() == []
    end

    test "cascades to entries" do
      {:ok, source} = Catalog.create_source(@source_attrs)

      {:ok, _entry} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "ext-1",
          title: "Title",
          status: "unread"
        })

      assert {:ok, _} = Catalog.delete_source(source)
      assert Catalog.list_entries() == []
    end
  end

  # Sinks

  describe "create_sink/1" do
    test "creates a sink with valid attrs" do
      assert {:ok, sink} = Catalog.create_sink(@sink_attrs)
      assert sink.type == "webhook"
    end

    test "returns error with invalid attrs" do
      assert {:error, _} = Catalog.create_sink(%{})
    end
  end

  describe "list_sinks/1" do
    test "returns all sinks" do
      {:ok, _} = Catalog.create_sink(@sink_attrs)
      assert [_] = Catalog.list_sinks()
    end
  end

  describe "get_sink!/1" do
    test "returns the sink" do
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      assert Catalog.get_sink!(sink.id).id == sink.id
    end
  end

  describe "update_sink/2" do
    test "updates the sink" do
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      assert {:ok, updated} = Catalog.update_sink(sink, %{name: "Updated"})
      assert updated.name == "Updated"
    end
  end

  describe "delete_sink/1" do
    test "deletes the sink" do
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      assert {:ok, _} = Catalog.delete_sink(sink)
      assert Catalog.list_sinks() == []
    end

    test "cascades to subscriptions" do
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      {:ok, _sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["elixir"]})
      assert {:ok, _} = Catalog.delete_sink(sink)
      assert Catalog.list_subscriptions() == []
    end
  end

  # Subscriptions

  describe "create_subscription/1" do
    test "creates a subscription" do
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      assert {:ok, sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["elixir"]})
      assert sub.tags == ["elixir"]
    end
  end

  describe "list_subscriptions/1" do
    test "returns all subscriptions" do
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      {:ok, _} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["elixir"]})
      assert [_] = Catalog.list_subscriptions()
    end

    test "filters by sink_id" do
      {:ok, s1} = Catalog.create_sink(@sink_attrs)
      {:ok, s2} = Catalog.create_sink(%{@sink_attrs | name: "Other"})
      {:ok, _} = Catalog.create_subscription(%{sink_id: s1.id, tags: ["a"]})
      {:ok, _} = Catalog.create_subscription(%{sink_id: s2.id, tags: ["b"]})

      assert [sub] = Catalog.list_subscriptions(sink_id: s1.id)
      assert sub.sink_id == s1.id
    end
  end

  describe "delete_subscription/1" do
    test "deletes the subscription" do
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      {:ok, sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["elixir"]})
      assert {:ok, _} = Catalog.delete_subscription(sub)
      assert Catalog.list_subscriptions() == []
    end
  end

  describe "subscriptions_for_tags/1" do
    test "returns subscriptions with overlapping tags" do
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      {:ok, _} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["elixir", "otp"]})
      {:ok, _} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["rust"]})

      results = Catalog.subscriptions_for_tags(["elixir"])
      assert length(results) == 1
      assert hd(results).tags == ["elixir", "otp"]
    end

    test "returns empty when no overlap" do
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      {:ok, _} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["elixir"]})

      assert [] = Catalog.subscriptions_for_tags(["python"])
    end
  end

  # Entries

  describe "create_entry/1" do
    test "creates an entry with valid attrs" do
      {:ok, source} = Catalog.create_source(@source_attrs)

      assert {:ok, entry} =
               Catalog.create_entry(%{
                 source_id: source.id,
                 external_id: "ext-1",
                 title: "Title",
                 status: "unread"
               })

      assert entry.external_id == "ext-1"
    end

    test "deduplicates on external_id + source_id" do
      {:ok, source} = Catalog.create_source(@source_attrs)

      attrs = %{
        source_id: source.id,
        external_id: "ext-dup",
        title: "Title",
        status: "unread"
      }

      assert {:ok, _first} = Catalog.create_entry(attrs)
      assert {:ok, _second} = Catalog.create_entry(attrs)
      assert length(Catalog.list_entries()) == 1
    end
  end

  describe "list_entries/1" do
    test "filters by status" do
      {:ok, source} = Catalog.create_source(@source_attrs)

      {:ok, _} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "e1",
          title: "T1",
          status: "unread"
        })

      {:ok, _} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "e2",
          title: "T2",
          status: "read"
        })

      assert [e] = Catalog.list_entries(status: "unread")
      assert e.status == "unread"
    end

    test "filters by source_id" do
      {:ok, s1} = Catalog.create_source(@source_attrs)
      {:ok, s2} = Catalog.create_source(%{@source_attrs | name: "Other"})

      {:ok, _} =
        Catalog.create_entry(%{
          source_id: s1.id,
          external_id: "e1",
          title: "T1",
          status: "unread"
        })

      {:ok, _} =
        Catalog.create_entry(%{
          source_id: s2.id,
          external_id: "e2",
          title: "T2",
          status: "unread"
        })

      assert [e] = Catalog.list_entries(source_id: s1.id)
      assert e.source_id == s1.id
    end

    test "supports limit" do
      {:ok, source} = Catalog.create_source(@source_attrs)

      for i <- 1..5 do
        {:ok, _} =
          Catalog.create_entry(%{
            source_id: source.id,
            external_id: "e#{i}",
            title: "T#{i}",
            status: "unread"
          })
      end

      assert length(Catalog.list_entries(limit: 2)) == 2
    end

    test "supports order with field and direction tuple" do
      {:ok, source} = Catalog.create_source(@source_attrs)

      {:ok, _} =
        Catalog.create_entry(%{source_id: source.id, external_id: "a", title: "A", status: "unread"})

      {:ok, _} =
        Catalog.create_entry(%{source_id: source.id, external_id: "b", title: "B", status: "unread"})

      entries = Catalog.list_entries(order: {:desc, :title})
      assert hd(entries).title == "B"
    end

    test "supports order with atom shorthand" do
      {:ok, source} = Catalog.create_source(@source_attrs)

      {:ok, _} =
        Catalog.create_entry(%{source_id: source.id, external_id: "b", title: "B", status: "unread"})

      {:ok, _} =
        Catalog.create_entry(%{source_id: source.id, external_id: "a", title: "A", status: "unread"})

      entries = Catalog.list_entries(order: :title)
      assert hd(entries).title == "A"
    end
  end

  describe "get_entry!/1" do
    test "returns the entry" do
      {:ok, source} = Catalog.create_source(@source_attrs)

      {:ok, entry} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "ext-1",
          title: "Title",
          status: "unread"
        })

      assert Catalog.get_entry!(entry.id).id == entry.id
    end
  end

  describe "update_entry/2" do
    test "updates the entry" do
      {:ok, source} = Catalog.create_source(@source_attrs)

      {:ok, entry} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "ext-1",
          title: "Title",
          status: "unread"
        })

      assert {:ok, updated} = Catalog.update_entry(entry, %{status: "read"})
      assert updated.status == "read"
    end
  end

  # entries_for_sink

  describe "entries_for_sink/2" do
    test "returns entries matching a sink's subscriptions by tag overlap" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      {:ok, _sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["elixir"]})

      {:ok, matching} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "e1",
          title: "Match",
          status: "unread",
          tags: ["elixir", "otp"]
        })

      {:ok, _non_matching} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "e2",
          title: "No Match",
          status: "unread",
          tags: ["python"]
        })

      results = Catalog.entries_for_sink(sink.id)
      assert length(results) == 1
      assert hd(results).id == matching.id
    end

    test "respects limit option" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
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

      results = Catalog.entries_for_sink(sink.id, limit: 2)
      assert length(results) == 2
    end

    test "returns empty list when no entries match" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      {:ok, _sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["rust"]})

      {:ok, _} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "e1",
          title: "Entry",
          status: "unread",
          tags: ["python"]
        })

      assert [] = Catalog.entries_for_sink(sink.id)
    end

    test "orders by inserted_at desc" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      {:ok, _sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["elixir"]})

      {:ok, _old} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "old",
          title: "Old",
          status: "unread",
          tags: ["elixir"]
        })

      Process.sleep(10)

      {:ok, _new} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "new",
          title: "New",
          status: "unread",
          tags: ["elixir"]
        })

      results = Catalog.entries_for_sink(sink.id)
      assert hd(results).title == "New"
    end

    test "deduplicates entries matched by multiple subscriptions" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      {:ok, _sub1} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["elixir"]})
      {:ok, _sub2} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["otp"]})

      {:ok, entry} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "e1",
          title: "Both Tags",
          status: "unread",
          tags: ["elixir", "otp"]
        })

      results = Catalog.entries_for_sink(sink.id)
      assert [only] = results
      assert only.id == entry.id
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
