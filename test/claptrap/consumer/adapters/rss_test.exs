defmodule Claptrap.Consumer.Adapters.RSSTest do
  use ExUnit.Case, async: false

  import Plug.Conn

  alias Claptrap.Consumer.Adapters.RSS
  alias Claptrap.Schemas.Source

  setup do
    Req.Test.set_req_test_to_shared()

    previous_options = Application.get_env(:claptrap, :rss_req_options, [])
    Application.put_env(:claptrap, :rss_req_options, plug: {Req.Test, RSS})

    on_exit(fn -> Application.put_env(:claptrap, :rss_req_options, previous_options) end)

    :ok
  end

  describe "validate_config/1" do
    test "accepts a config with a url" do
      assert :ok = RSS.validate_config(%{"url" => "https://example.com/feed.xml"})
    end

    test "rejects a config without a url" do
      assert {:error, _reason} = RSS.validate_config(%{})
    end
  end

  describe "fetch/1" do
    test "returns normalized attrs for an RSS 2.0 feed" do
      Req.Test.expect(RSS, fn conn ->
        send_resp(conn, 200, rss_feed())
      end)

      assert {:ok, [entry]} = RSS.fetch(source())
      assert entry.external_id == "guid-1"
      assert entry.title == "First post"
      assert entry.summary == "A summary"
      assert entry.url == "https://example.com/posts/1"
      assert entry.author == "Ada Lovelace"
      assert entry.tags == ["elixir", "otp"]
      assert %DateTime{} = entry.published_at
    end

    test "returns normalized attrs for an Atom feed" do
      Req.Test.expect(RSS, fn conn ->
        send_resp(conn, 200, atom_feed())
      end)

      assert {:ok, [entry]} = RSS.fetch(source())
      assert entry.external_id == "urn:uuid:1"
      assert entry.title == "Atom entry"
      assert entry.summary == "Atom summary"
      assert entry.url == "https://example.com/atom/1"
      assert entry.author == "Grace Hopper"
      assert entry.tags == ["atom"]
      assert %DateTime{} = entry.published_at
    end

    test "normalizes RFC 822 numeric offsets to UTC" do
      Req.Test.expect(RSS, fn conn ->
        send_resp(conn, 200, offset_rss_feed())
      end)

      assert {:ok, [entry]} = RSS.fetch(source())
      assert entry.published_at == ~U[2026-03-18 02:30:00Z]
    end

    test "accepts RFC 822 dates without seconds" do
      Req.Test.expect(RSS, fn conn ->
        send_resp(conn, 200, no_seconds_rss_feed())
      end)

      assert {:ok, [entry]} = RSS.fetch(source())
      assert entry.published_at == ~U[2026-03-18 12:00:00Z]
    end

    test "returns transient errors for 500 responses" do
      Req.Test.expect(RSS, fn conn ->
        send_resp(conn, 500, "boom")
      end)

      assert {:error, {:http_error, 500}} = RSS.fetch(source())
    end

    @tag capture_log: true
    test "raises on malformed xml" do
      Req.Test.expect(RSS, fn conn ->
        send_resp(conn, 200, "<rss><channel><item></rss>")
      end)

      assert_raise ArgumentError, ~r/unable to parse RSS\/Atom feed/, fn ->
        RSS.fetch(source())
      end
    end

    test "fills optional fields with nil or defaults" do
      Req.Test.expect(RSS, fn conn ->
        send_resp(conn, 200, minimal_rss_feed())
      end)

      assert {:ok, [entry]} = RSS.fetch(source())
      assert entry.title == "(untitled)"
      assert entry.summary == nil
      assert entry.url == "https://example.com/minimal"
      assert entry.author == nil
      assert entry.published_at == nil
      assert entry.tags == []
    end
  end

  defp source(config \\ %{"url" => "https://example.com/feed.xml"}) do
    %Source{id: Ecto.UUID.generate(), type: "rss", name: "Feed", config: config, tags: []}
  end

  defp rss_feed do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/">
      <channel>
        <title>Example Feed</title>
        <item>
          <guid>guid-1</guid>
          <title>First post</title>
          <description>A summary</description>
          <link>https://example.com/posts/1</link>
          <dc:creator>Ada Lovelace</dc:creator>
          <pubDate>Tue, 18 Mar 2026 00:00:00 GMT</pubDate>
          <category>elixir</category>
          <category>otp</category>
        </item>
      </channel>
    </rss>
    """
  end

  defp atom_feed do
    """
    <?xml version="1.0" encoding="utf-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom">
      <title>Example Atom</title>
      <entry>
        <id>urn:uuid:1</id>
        <title>Atom entry</title>
        <summary>Atom summary</summary>
        <link href="https://example.com/atom/1" />
        <author>
          <name>Grace Hopper</name>
        </author>
        <published>2026-03-18T00:00:00Z</published>
        <category term="atom" />
      </entry>
    </feed>
    """
  end

  defp offset_rss_feed do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>Offset Feed</title>
        <item>
          <guid>guid-offset</guid>
          <title>Offset post</title>
          <link>https://example.com/offset</link>
          <pubDate>Tue, 18 Mar 2026 00:30:00 -0200</pubDate>
        </item>
      </channel>
    </rss>
    """
  end

  defp no_seconds_rss_feed do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>No Seconds Feed</title>
        <item>
          <guid>guid-no-seconds</guid>
          <title>No Seconds</title>
          <link>https://example.com/no-seconds</link>
          <pubDate>Tue, 18 Mar 2026 12:00 +0000</pubDate>
        </item>
      </channel>
    </rss>
    """
  end

  defp minimal_rss_feed do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>Minimal Feed</title>
        <item>
          <link>https://example.com/minimal</link>
        </item>
      </channel>
    </rss>
    """
  end
end
