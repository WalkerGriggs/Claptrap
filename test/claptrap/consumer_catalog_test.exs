defmodule Claptrap.Integration.ConsumerCatalogTest do
  use Claptrap.DataCase, async: true

  @moduletag :integration
  @moduletag capture_log: true

  alias Claptrap.Catalog

  @source_attrs %{type: "rss", name: "Test Feed", config: %{"url" => "https://example.com/feed.xml"}}

  defp create_source!(attrs \\ %{}) do
    {:ok, source} = Catalog.create_source(Map.merge(@source_attrs, attrs))
    source
  end

  defp entry_attrs(source, overrides) do
    Map.merge(
      %{
        source_id: source.id,
        external_id: "ext-#{System.unique_integer([:positive])}",
        title: "Test Entry",
        summary: "A summary",
        url: "https://example.com/post",
        author: "Author",
        published_at: ~U[2026-03-01 12:00:00.000000Z],
        status: "unread",
        metadata: %{"word_count" => 500},
        tags: ["elixir"]
      },
      overrides
    )
  end

  describe "entry ingestion roundtrip" do
    test "all fields set by a consumer adapter are persisted and queryable" do
      source = create_source!()

      attrs =
        entry_attrs(source, %{
          external_id: "roundtrip-1",
          title: "Roundtrip Title",
          summary: "Roundtrip Summary",
          url: "https://example.com/roundtrip",
          author: "Jane Doe",
          published_at: ~U[2026-03-15 08:30:00.000000Z],
          status: "unread",
          metadata: %{"site" => "example.com"},
          tags: ["elixir", "otp"]
        })

      {:ok, entry} = Catalog.create_entry(attrs)
      reloaded = Catalog.get_entry!(entry.id)
      expected_source_id = source.id

      assert %{
               source_id: ^expected_source_id,
               external_id: "roundtrip-1",
               title: "Roundtrip Title",
               summary: "Roundtrip Summary",
               url: "https://example.com/roundtrip",
               author: "Jane Doe",
               published_at: ~U[2026-03-15 08:30:00.000000Z],
               status: "unread",
               metadata: %{"site" => "example.com"},
               tags: ["elixir", "otp"]
             } = reloaded
    end

    test "entries are filterable by source_id" do
      s1 = create_source!(%{name: "Source A"})
      s2 = create_source!(%{name: "Source B"})

      {:ok, _} = Catalog.create_entry(entry_attrs(s1, %{external_id: "a1"}))
      {:ok, _} = Catalog.create_entry(entry_attrs(s2, %{external_id: "b1"}))

      assert [%{source_id: sid}] = Catalog.list_entries(source_id: s1.id)
      assert sid == s1.id
    end

    test "entries are filterable by status" do
      source = create_source!()
      {:ok, _} = Catalog.create_entry(entry_attrs(source, %{external_id: "u1", status: "unread"}))
      {:ok, _} = Catalog.create_entry(entry_attrs(source, %{external_id: "r1", status: "read"}))

      assert [%{status: "read"}] = Catalog.list_entries(status: "read")
    end
  end

  describe "source tag inheritance" do
    test "source tags merge with adapter-produced tags on an entry" do
      source = create_source!(%{tags: ["tech", "news"]})
      merged_tags = Enum.uniq(source.tags ++ ["elixir"])

      {:ok, entry} = Catalog.create_entry(entry_attrs(source, %{tags: merged_tags}))

      assert %{tags: ["tech", "news", "elixir"]} = Catalog.get_entry!(entry.id)
    end

    test "source with no tags produces entries with only adapter tags" do
      source = create_source!(%{tags: []})
      {:ok, entry} = Catalog.create_entry(entry_attrs(source, %{tags: ["elixir"]}))

      assert %{tags: ["elixir"]} = Catalog.get_entry!(entry.id)
    end

    test "duplicate tags are removed when merging" do
      source = create_source!(%{tags: ["elixir"]})
      merged = Enum.uniq(source.tags ++ ["elixir", "otp"])

      {:ok, entry} = Catalog.create_entry(entry_attrs(source, %{tags: merged}))

      assert %{tags: ["elixir", "otp"]} = Catalog.get_entry!(entry.id)
    end
  end

  describe "deduplication across poll cycles" do
    test "re-ingesting the same (source_id, external_id) does not create a duplicate" do
      source = create_source!()
      attrs = entry_attrs(source, %{external_id: "dup-1"})

      {:ok, first} = Catalog.create_entry(attrs)
      {:ok, _second} = Catalog.create_entry(attrs)

      assert [%{id: id}] = Catalog.list_entries(source_id: source.id)
      assert id == first.id
    end

    test "dedup returns {:ok, _} without inserting a new row" do
      source = create_source!()
      attrs = entry_attrs(source, %{external_id: "dup-2"})

      {:ok, first} = Catalog.create_entry(attrs)
      assert {:ok, _second} = Catalog.create_entry(attrs)

      assert [%{id: id}] = Catalog.list_entries(source_id: source.id)
      assert id == first.id
    end
  end

  describe "cross-source namespace isolation" do
    test "two sources can each have an entry with the same external_id" do
      s1 = create_source!(%{name: "Source A"})
      s2 = create_source!(%{name: "Source B"})

      {:ok, e1} = Catalog.create_entry(entry_attrs(s1, %{external_id: "shared-guid"}))
      {:ok, e2} = Catalog.create_entry(entry_attrs(s2, %{external_id: "shared-guid"}))

      assert e1.id != e2.id
      assert length(Catalog.list_entries()) == 2
    end

    test "dedup still works within each source independently" do
      s1 = create_source!(%{name: "Source A"})
      s2 = create_source!(%{name: "Source B"})

      {:ok, _} = Catalog.create_entry(entry_attrs(s1, %{external_id: "shared-guid"}))
      {:ok, _} = Catalog.create_entry(entry_attrs(s1, %{external_id: "shared-guid"}))
      {:ok, _} = Catalog.create_entry(entry_attrs(s2, %{external_id: "shared-guid"}))
      {:ok, _} = Catalog.create_entry(entry_attrs(s2, %{external_id: "shared-guid"}))

      assert length(Catalog.list_entries(source_id: s1.id)) == 1
      assert length(Catalog.list_entries(source_id: s2.id)) == 1
    end
  end

  describe "source last_consumed_at tracks progress" do
    test "updating last_consumed_at records consumption progress" do
      source = create_source!()
      assert %{last_consumed_at: nil} = source

      now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
      {:ok, updated} = Catalog.update_source(source, %{last_consumed_at: now})

      assert %{last_consumed_at: ^now} = updated
      assert %{last_consumed_at: ^now} = Catalog.get_source!(source.id)
    end

    test "last_consumed_at is preserved across re-reads" do
      source = create_source!()
      now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
      {:ok, _} = Catalog.update_source(source, %{last_consumed_at: now})

      assert %{last_consumed_at: ^now} = Catalog.get_source!(source.id)
    end
  end

  describe "invalid entry attrs are rejected" do
    test "missing required fields returns error changeset" do
      source = create_source!()

      assert {:error, %{valid?: false}} = Catalog.create_entry(%{source_id: source.id})
      assert [] = Catalog.list_entries()
    end

    test "missing title is rejected" do
      source = create_source!()

      assert {:error, changeset} =
               Catalog.create_entry(%{source_id: source.id, external_id: "no-title", status: "unread"})

      assert %{title: _} = errors_on(changeset)
    end

    test "invalid status is rejected" do
      source = create_source!()

      assert {:error, changeset} =
               Catalog.create_entry(%{
                 source_id: source.id,
                 external_id: "bad-status",
                 title: "Title",
                 status: "invalid_status"
               })

      assert %{status: _} = errors_on(changeset)
    end

    test "no partial rows are left behind after validation failure" do
      source = create_source!()
      {:error, _} = Catalog.create_entry(%{source_id: source.id})
      {:error, _} = Catalog.create_entry(%{source_id: source.id, external_id: "x"})

      assert [] = Catalog.list_entries()
    end
  end

  describe "bulk ingestion from single poll" do
    test "N items with distinct external_ids create N entries" do
      source = create_source!()

      for i <- 1..5 do
        {:ok, _} = Catalog.create_entry(entry_attrs(source, %{external_id: "bulk-#{i}", title: "Entry #{i}"}))
      end

      assert length(Catalog.list_entries(source_id: source.id)) == 5
    end

    test "each entry preserves its own provenance" do
      source = create_source!()

      for i <- 1..3 do
        {:ok, _} =
          Catalog.create_entry(
            entry_attrs(source, %{external_id: "prov-#{i}", title: "Title #{i}", author: "Author #{i}"})
          )
      end

      entries = Catalog.list_entries(source_id: source.id, order: :external_id)
      titles = Enum.map(entries, & &1.title)

      assert MapSet.new(["Title 1", "Title 2", "Title 3"]) == MapSet.new(titles)
    end
  end

  describe "coordinator reads enabled sources" do
    test "list_sources(enabled: true) returns only enabled sources" do
      create_source!(%{name: "Enabled Feed", enabled: true})
      create_source!(%{name: "Disabled Feed", enabled: false})

      assert [%{name: "Enabled Feed", enabled: true}] = Catalog.list_sources(enabled: true)
    end

    test "list_sources(enabled: false) returns only disabled sources" do
      create_source!(%{name: "Enabled Feed", enabled: true})
      create_source!(%{name: "Disabled Feed", enabled: false})

      assert [%{name: "Disabled Feed", enabled: false}] = Catalog.list_sources(enabled: false)
    end

    test "list_sources with no filter returns all" do
      create_source!(%{name: "A"})
      create_source!(%{name: "B", enabled: false})

      assert length(Catalog.list_sources()) == 2
    end
  end

  describe "source deletion cascades to entries" do
    test "deleting a source removes all its entries" do
      source = create_source!()

      for i <- 1..3 do
        {:ok, _} = Catalog.create_entry(entry_attrs(source, %{external_id: "cascade-#{i}"}))
      end

      assert length(Catalog.list_entries(source_id: source.id)) == 3

      {:ok, _} = Catalog.delete_source(source)
      assert [] = Catalog.list_entries()
    end

    test "deleting one source does not affect another source's entries" do
      s1 = create_source!(%{name: "Source A"})
      s2 = create_source!(%{name: "Source B"})

      {:ok, _} = Catalog.create_entry(entry_attrs(s1, %{external_id: "a1"}))
      {:ok, _} = Catalog.create_entry(entry_attrs(s2, %{external_id: "b1"}))

      {:ok, _} = Catalog.delete_source(s1)

      assert [] = Catalog.list_entries(source_id: s1.id)
      assert [%{source_id: sid}] = Catalog.list_entries(source_id: s2.id)
      assert sid == s2.id
    end
  end

  describe "entry status lifecycle" do
    test "entries start as unread and transition through valid statuses" do
      source = create_source!()
      {:ok, entry} = Catalog.create_entry(entry_attrs(source, %{status: "unread"}))
      assert %{status: "unread"} = entry

      {:ok, updated} = Catalog.update_entry(entry, %{status: "in_progress"})
      assert %{status: "in_progress"} = updated

      {:ok, updated} = Catalog.update_entry(updated, %{status: "read"})
      assert %{status: "read"} = updated

      {:ok, updated} = Catalog.update_entry(updated, %{status: "archived"})
      assert %{status: "archived"} = updated
    end

    test "invalid status transition is rejected" do
      source = create_source!()
      {:ok, entry} = Catalog.create_entry(entry_attrs(source, %{status: "unread"}))

      assert {:error, changeset} = Catalog.update_entry(entry, %{status: "deleted"})
      assert %{status: _} = errors_on(changeset)
      assert %{status: "unread"} = Catalog.get_entry!(entry.id)
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
