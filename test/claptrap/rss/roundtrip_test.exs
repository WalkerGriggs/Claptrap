defmodule Claptrap.RSS.RoundtripTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Claptrap.RSS
  alias Claptrap.RSS.{Enclosure, Generators, Guid, ParseError, Source}

  # -- Roundtrip property tests -------------------------------------------

  describe "roundtrip: parse(generate(feed)) preserves data" do
    property "channel-level scalar fields survive roundtrip" do
      check all(feed <- Generators.feed(), max_runs: 100) do
        {:ok, xml} = RSS.generate(feed)
        {:ok, parsed} = RSS.parse(xml)

        assert parsed.title == feed.title
        assert parsed.link == feed.link
        assert parsed.description == feed.description
        assert parsed.language == feed.language
        assert parsed.copyright == feed.copyright
        assert parsed.managing_editor == feed.managing_editor
        assert parsed.web_master == feed.web_master
        assert parsed.generator == feed.generator
        assert parsed.docs == feed.docs
        assert parsed.rating == feed.rating
      end
    end

    property "ttl survives roundtrip as integer" do
      check all(feed <- Generators.feed(), max_runs: 100) do
        {:ok, xml} = RSS.generate(feed)
        {:ok, parsed} = RSS.parse(xml)

        assert parsed.ttl == feed.ttl
      end
    end

    property "nil optional fields remain nil after roundtrip" do
      check all(feed <- Generators.feed(), max_runs: 100) do
        {:ok, xml} = RSS.generate(feed)
        {:ok, parsed} = RSS.parse(xml)

        if feed.language == nil, do: assert(parsed.language == nil)
        if feed.copyright == nil, do: assert(parsed.copyright == nil)
        if feed.managing_editor == nil, do: assert(parsed.managing_editor == nil)
        if feed.web_master == nil, do: assert(parsed.web_master == nil)
        if feed.generator == nil, do: assert(parsed.generator == nil)
        if feed.docs == nil, do: assert(parsed.docs == nil)
        if feed.ttl == nil, do: assert(parsed.ttl == nil)
        if feed.rating == nil, do: assert(parsed.rating == nil)
      end
    end

    property "datetime fields roundtrip to same instant (UTC)" do
      check all(feed <- Generators.feed(), max_runs: 100) do
        {:ok, xml} = RSS.generate(feed)
        {:ok, parsed} = RSS.parse(xml)

        assert_datetimes_equal(parsed.pub_date, feed.pub_date)
        assert_datetimes_equal(parsed.last_build_date, feed.last_build_date)
      end
    end

    property "item count is preserved" do
      check all(feed <- Generators.feed(), max_runs: 100) do
        {:ok, xml} = RSS.generate(feed)
        {:ok, parsed} = RSS.parse(xml)

        assert length(parsed.items) == length(feed.items)
      end
    end

    property "item order is preserved" do
      check all(feed <- Generators.feed(), max_runs: 100) do
        {:ok, xml} = RSS.generate(feed)
        {:ok, parsed} = RSS.parse(xml)

        Enum.zip(feed.items, parsed.items)
        |> Enum.each(fn {orig, roundtripped} ->
          assert roundtripped.title == orig.title
          assert roundtripped.description == orig.description
        end)
      end
    end

    property "item scalar fields survive roundtrip" do
      check all(feed <- Generators.feed(), max_runs: 100) do
        {:ok, xml} = RSS.generate(feed)
        {:ok, parsed} = RSS.parse(xml)

        Enum.zip(feed.items, parsed.items)
        |> Enum.each(fn {orig, roundtripped} ->
          assert roundtripped.title == orig.title
          assert roundtripped.link == orig.link
          assert roundtripped.description == orig.description
          assert roundtripped.author == orig.author
          assert roundtripped.comments == orig.comments
          assert_datetimes_equal(roundtripped.pub_date, orig.pub_date)
        end)
      end
    end

    property "item enclosure survives roundtrip" do
      check all(feed <- Generators.feed(), max_runs: 100) do
        {:ok, xml} = RSS.generate(feed)
        {:ok, parsed} = RSS.parse(xml)

        Enum.zip(feed.items, parsed.items)
        |> Enum.each(fn {orig, roundtripped} ->
          case orig.enclosure do
            nil ->
              assert roundtripped.enclosure == nil

            %Enclosure{} = enc ->
              assert roundtripped.enclosure.url == enc.url
              assert roundtripped.enclosure.length == enc.length
              assert roundtripped.enclosure.type == enc.type
          end
        end)
      end
    end

    property "item guid survives roundtrip" do
      check all(feed <- Generators.feed(), max_runs: 100) do
        {:ok, xml} = RSS.generate(feed)
        {:ok, parsed} = RSS.parse(xml)

        Enum.zip(feed.items, parsed.items)
        |> Enum.each(fn {orig, roundtripped} ->
          case orig.guid do
            nil ->
              assert roundtripped.guid == nil

            %Guid{} = guid ->
              assert roundtripped.guid.value == guid.value
              assert roundtripped.guid.is_perma_link == guid.is_perma_link
          end
        end)
      end
    end

    property "item source survives roundtrip" do
      check all(feed <- Generators.feed(), max_runs: 100) do
        {:ok, xml} = RSS.generate(feed)
        {:ok, parsed} = RSS.parse(xml)

        Enum.zip(feed.items, parsed.items)
        |> Enum.each(fn {orig, roundtripped} ->
          case orig.source do
            nil ->
              assert roundtripped.source == nil

            %Source{} = src ->
              assert roundtripped.source.value == src.value
              assert roundtripped.source.url == src.url
          end
        end)
      end
    end

    property "category order is preserved at channel and item level" do
      check all(feed <- Generators.feed(), max_runs: 100) do
        {:ok, xml} = RSS.generate(feed)
        {:ok, parsed} = RSS.parse(xml)

        assert_categories_equal(parsed.categories, feed.categories)

        Enum.zip(feed.items, parsed.items)
        |> Enum.each(fn {orig, roundtripped} ->
          assert_categories_equal(roundtripped.categories, orig.categories)
        end)
      end
    end

    property "cloud survives roundtrip" do
      check all(feed <- Generators.feed(), max_runs: 100) do
        {:ok, xml} = RSS.generate(feed)
        {:ok, parsed} = RSS.parse(xml)

        case feed.cloud do
          nil ->
            assert parsed.cloud == nil

          cloud ->
            assert parsed.cloud.domain == cloud.domain
            assert parsed.cloud.port == cloud.port
            assert parsed.cloud.path == cloud.path
            assert parsed.cloud.register_procedure == cloud.register_procedure
            assert parsed.cloud.protocol == cloud.protocol
        end
      end
    end

    property "image survives roundtrip" do
      check all(feed <- Generators.feed(), max_runs: 100) do
        {:ok, xml} = RSS.generate(feed)
        {:ok, parsed} = RSS.parse(xml)

        case feed.image do
          nil ->
            assert parsed.image == nil

          img ->
            assert parsed.image.url == img.url
            assert parsed.image.title == img.title
            assert parsed.image.link == img.link
            assert parsed.image.width == img.width
            assert parsed.image.height == img.height
            assert parsed.image.description == img.description
        end
      end
    end

    property "text_input survives roundtrip" do
      check all(feed <- Generators.feed(), max_runs: 100) do
        {:ok, xml} = RSS.generate(feed)
        {:ok, parsed} = RSS.parse(xml)

        case feed.text_input do
          nil ->
            assert parsed.text_input == nil

          ti ->
            assert parsed.text_input.title == ti.title
            assert parsed.text_input.description == ti.description
            assert parsed.text_input.name == ti.name
            assert parsed.text_input.link == ti.link
        end
      end
    end

    property "skip_hours survives roundtrip" do
      check all(feed <- Generators.feed(), max_runs: 100) do
        {:ok, xml} = RSS.generate(feed)
        {:ok, parsed} = RSS.parse(xml)

        assert parsed.skip_hours == feed.skip_hours
      end
    end

    property "skip_days survives roundtrip" do
      check all(feed <- Generators.feed(), max_runs: 100) do
        {:ok, xml} = RSS.generate(feed)
        {:ok, parsed} = RSS.parse(xml)

        assert parsed.skip_days == feed.skip_days
      end
    end
  end

  # -- Adversarial parser tests -------------------------------------------

  describe "adversarial input" do
    test "truncated XML returns error, never raises" do
      result = RSS.parse("<rss><channel><title>Trun")
      assert {:error, %ParseError{}} = result
    end

    test "binary garbage returns error, never raises" do
      result = RSS.parse(<<0xFF, 0xFE, 0x00, 0x01, 0xAB, 0xCD>>)
      assert {:error, %ParseError{}} = result
    end

    test "valid XML but not RSS returns error" do
      html = """
      <?xml version="1.0"?>
      <html><body><p>Not RSS</p></body></html>
      """

      assert {:error, %ParseError{}} = RSS.parse(html)
    end

    test "empty document returns error" do
      assert {:error, %ParseError{}} = RSS.parse("")
    end

    test "nil input returns error" do
      assert {:error, %ParseError{}} = RSS.parse(nil)
    end

    test "large feed with many items completes without hanging" do
      items =
        Enum.map_join(1..1000, "\n", fn i ->
          "<item><title>Item #{i}</title></item>"
        end)

      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Large Feed</title>
          <link>https://example.com</link>
          <description>A very large feed</description>
          #{items}
        </channel>
      </rss>
      """

      assert {:ok, feed} = RSS.parse(xml)
      assert length(feed.items) == 1000
    end

    property "random binaries never raise, always return ok or error tuple" do
      check all(bin <- binary(min_length: 0, max_length: 500)) do
        result = RSS.parse(bin)
        assert match?({:ok, _}, result) or match?({:error, %ParseError{}}, result)
      end
    end

    property "random printable strings never raise" do
      check all(str <- string(:printable, min_length: 0, max_length: 500)) do
        result = RSS.parse(str)
        assert match?({:ok, _}, result) or match?({:error, %ParseError{}}, result)
      end
    end
  end

  # -- Helpers ------------------------------------------------------------

  defp assert_datetimes_equal(nil, nil), do: :ok

  defp assert_datetimes_equal(%DateTime{} = a, %DateTime{} = b) do
    assert DateTime.truncate(a, :second) == DateTime.truncate(b, :second),
           "expected #{inspect(a)} to equal #{inspect(b)}"
  end

  defp assert_datetimes_equal(a, b) do
    flunk("datetime mismatch: #{inspect(a)} vs #{inspect(b)}")
  end

  defp assert_categories_equal(parsed_cats, orig_cats) do
    assert length(parsed_cats) == length(orig_cats)

    Enum.zip(orig_cats, parsed_cats)
    |> Enum.each(fn {orig, roundtripped} ->
      assert roundtripped.value == orig.value
      assert roundtripped.domain == orig.domain
    end)
  end
end
