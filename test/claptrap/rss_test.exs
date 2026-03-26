defmodule Claptrap.RSSTest do
  use ExUnit.Case, async: true

  alias Claptrap.RSS
  alias Claptrap.RSS.{Feed, GenerateError, ParseError}

  @feed %Feed{title: "Test", link: "https://example.com", description: "A test feed"}

  describe "parse!/2" do
    test "raises ParseError when given invalid input" do
      assert_raise ParseError, fn ->
        RSS.parse!("<not-rss/>")
      end
    end

    test "raises ParseError in strict mode for malformed item pubDate" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Test Feed</title>
          <link>https://example.com</link>
          <description>A test feed</description>
          <item>
            <title>Bad Date Item</title>
            <pubDate>not-a-date</pubDate>
          </item>
        </channel>
      </rss>
      """

      assert_raise ParseError, "malformed date: not-a-date", fn ->
        RSS.parse!(xml, strict: true)
      end
    end
  end

  describe "generate!/2" do
    test "returns binary for valid feeds" do
      assert xml = RSS.generate!(@feed)
      assert is_binary(xml)
    end

    test "raises GenerateError for invalid feeds" do
      assert_raise GenerateError, fn ->
        RSS.generate!(%{@feed | title: ""})
      end
    end
  end

  describe "parse/2" do
    test "returns {:error, %ParseError{}} for invalid input" do
      assert {:error, %ParseError{}} = RSS.parse("<not-rss/>")
    end
  end

  describe "generate/2" do
    test "returns {:ok, binary} for valid feed" do
      assert {:ok, xml} = RSS.generate(@feed)
      assert is_binary(xml)
    end

    test "returns {:error, %GenerateError{}} for invalid feed" do
      assert {:error, %GenerateError{}} = RSS.generate(%{@feed | title: ""})
    end
  end

  describe "validate/1" do
    test "returns :ok for a valid feed" do
      assert :ok = RSS.validate(@feed)
    end

    test "returns {:error, errors} for an invalid feed" do
      bad_feed = %{@feed | title: ""}
      assert {:error, errors} = RSS.validate(bad_feed)
      assert is_list(errors)
    end
  end
end
