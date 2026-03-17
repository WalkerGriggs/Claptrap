defmodule Claptrap.Consumer.Adapters.RSSTest do
  use ExUnit.Case, async: true

  alias Claptrap.Consumer.Adapters.RSS

  @rss2_feed """
  <?xml version="1.0" encoding="UTF-8"?>
  <rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
      <title>Test Feed</title>
      <link>https://example.com</link>
      <item>
        <guid>https://example.com/post-1</guid>
        <title>First Post</title>
        <description>A summary of the first post</description>
        <link>https://example.com/post-1</link>
        <author>author@example.com</author>
        <pubDate>Mon, 01 Jan 2024 12:00:00 +0000</pubDate>
        <category>elixir</category>
        <category>erlang</category>
      </item>
      <item>
        <title>Second Post</title>
        <link>https://example.com/post-2</link>
      </item>
    </channel>
  </rss>
  """

  @atom_feed """
  <?xml version="1.0" encoding="UTF-8"?>
  <feed xmlns="http://www.w3.org/2005/Atom">
    <title>Atom Test Feed</title>
    <entry>
      <id>tag:example.com,2024:1</id>
      <title>Atom Entry One</title>
      <link href="https://example.com/atom-1"/>
      <summary>Atom summary</summary>
      <author><name>Jane Doe</name></author>
      <published>2024-01-01T12:00:00Z</published>
      <category term="elixir"/>
    </entry>
  </feed>
  """

  defp source_with_url(url) do
    %Claptrap.Schemas.Source{
      id: "test-id",
      type: "rss",
      name: "Test",
      config: %{"url" => url},
      tags: [],
      enabled: true
    }
  end

  defp stub_http(body, status \\ 200) do
    Req.Test.stub(:rss_test, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.send_resp(status, body)
    end)

    Application.put_env(:claptrap, :req_test_plug, {Req.Test, :rss_test})
    on_exit(fn -> Application.delete_env(:claptrap, :req_test_plug) end)
  end

  describe "validate_config/1" do
    test "accepts config with url key" do
      assert :ok = RSS.validate_config(%{"url" => "https://example.com/feed.rss"})
    end

    test "rejects config missing url" do
      assert {:error, _} = RSS.validate_config(%{})
    end

    test "rejects config with empty url" do
      assert {:error, _} = RSS.validate_config(%{"url" => ""})
    end

    test "rejects nil config" do
      assert {:error, _} = RSS.validate_config(nil)
    end
  end

  describe "mode/0" do
    test "returns :pull" do
      assert RSS.mode() == :pull
    end
  end

  describe "fetch/1 with RSS 2.0 feed" do
    setup do
      stub_http(@rss2_feed)
      :ok
    end

    test "returns normalized entry attrs for all items" do
      source = source_with_url("https://example.com/feed.rss")
      assert {:ok, entries} = RSS.fetch(source)
      assert length(entries) == 2
    end

    test "normalizes first item correctly" do
      source = source_with_url("https://example.com/feed.rss")
      assert {:ok, [first | _]} = RSS.fetch(source)
      assert first.external_id == "https://example.com/post-1"
      assert first.title == "First Post"
      assert first.summary == "A summary of the first post"
      assert first.url == "https://example.com/post-1"
      assert first.tags == ["elixir", "erlang"]
      assert first.status == "unread"
      assert %DateTime{} = first.published_at
    end

    test "falls back to link when guid absent" do
      source = source_with_url("https://example.com/feed.rss")
      assert {:ok, [_, second]} = RSS.fetch(source)
      assert second.external_id == "https://example.com/post-2"
    end
  end

  describe "fetch/1 - missing optional fields" do
    test "defaults title to (untitled) when absent" do
      stub_http("""
      <?xml version="1.0"?>
      <rss version="2.0"><channel>
        <item><guid>x</guid><link>https://example.com/x</link></item>
      </channel></rss>
      """)

      source = source_with_url("https://example.com/feed.rss")
      assert {:ok, [entry]} = RSS.fetch(source)
      assert entry.title == "(untitled)"
    end

    test "optional fields are nil when absent" do
      stub_http("""
      <?xml version="1.0"?>
      <rss version="2.0"><channel>
        <item><guid>y</guid><title>Hello</title></item>
      </channel></rss>
      """)

      source = source_with_url("https://example.com/feed.rss")
      assert {:ok, [entry]} = RSS.fetch(source)
      assert is_nil(entry.summary)
      assert is_nil(entry.url)
      assert is_nil(entry.author)
      assert is_nil(entry.published_at)
      assert entry.tags == []
    end
  end

  describe "fetch/1 with Atom feed" do
    setup do
      stub_http(@atom_feed)
      :ok
    end

    test "returns normalized entry attrs" do
      source = source_with_url("https://example.com/atom.xml")
      assert {:ok, [entry]} = RSS.fetch(source)
      assert entry.external_id == "tag:example.com,2024:1"
      assert entry.title == "Atom Entry One"
      assert entry.summary == "Atom summary"
      assert entry.url == "https://example.com/atom-1"
      assert entry.author == "Jane Doe"
      assert entry.tags == ["elixir"]
      assert %DateTime{} = entry.published_at
    end
  end

  describe "fetch/1 error handling" do
    test "returns error on HTTP 5xx" do
      stub_http("Service Unavailable", 503)
      source = source_with_url("https://example.com/feed.rss")
      assert {:error, {:http_error, 503}} = RSS.fetch(source)
    end

    test "raises ArgumentError on invalid config" do
      source = %{source_with_url("https://example.com/feed.rss") | config: %{}}

      assert_raise ArgumentError, fn ->
        RSS.fetch(source)
      end
    end
  end
end
