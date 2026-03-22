defmodule Claptrap.RSS.PlugTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  alias Claptrap.RSS.{Feed, Plug}

  defp minimal_feed do
    Feed.new("Test", "https://example.com", "A test feed")
  end

  describe "init/1" do
    test "raises KeyError when feed_fn is missing" do
      assert_raise KeyError, fn ->
        Plug.init([])
      end
    end

    test "returns config map with defaults" do
      opts = Plug.init(feed_fn: fn _conn -> minimal_feed() end)

      assert is_function(opts.feed_fn, 1)
      assert opts.content_type == "application/rss+xml; charset=utf-8"
      assert opts.cache_control == nil
    end
  end

  describe "successful feed serving" do
    test "serves a valid RSS feed with 200 status" do
      feed = minimal_feed()
      opts = Plug.init(feed_fn: fn _conn -> feed end)
      conn = conn(:get, "/feed") |> Plug.call(opts)

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> hd() =~ "application/rss+xml"
      {:ok, parsed} = Claptrap.RSS.parse(conn.resp_body)
      assert parsed.title == "Test"
    end

    test "response body is parseable XML" do
      feed = minimal_feed()
      opts = Plug.init(feed_fn: fn _conn -> feed end)
      conn = conn(:get, "/feed") |> Plug.call(opts)

      assert conn.resp_body =~ "<?xml"
      assert conn.resp_body =~ "<rss"
      assert conn.resp_body =~ "<channel>"
    end
  end

  describe "error handling" do
    test "returns 404 when feed_fn returns {:error, :not_found}" do
      opts = Plug.init(feed_fn: fn _conn -> {:error, :not_found} end)
      conn = conn(:get, "/feed") |> Plug.call(opts)

      assert conn.status == 404
      assert conn.resp_body == "Not Found"
    end

    test "returns 500 when feed_fn returns {:error, reason}" do
      opts = Plug.init(feed_fn: fn _conn -> {:error, :something_else} end)
      conn = conn(:get, "/feed") |> Plug.call(opts)

      assert conn.status == 500
      assert conn.resp_body == "Internal Server Error"
    end

    test "returns 500 when generate fails on invalid feed" do
      invalid_feed = %Feed{title: "", link: "https://example.com", description: "desc"}
      opts = Plug.init(feed_fn: fn _conn -> invalid_feed end)
      conn = conn(:get, "/feed") |> Plug.call(opts)

      assert conn.status == 500
      assert conn.resp_body == "Internal Server Error"
    end
  end

  describe "cache-control header" do
    test "adds Cache-Control header when option is set" do
      feed = minimal_feed()
      opts = Plug.init(feed_fn: fn _conn -> feed end, cache_control: "public, max-age=900")
      conn = conn(:get, "/feed") |> Plug.call(opts)

      assert get_resp_header(conn, "cache-control") == ["public, max-age=900"]
    end

    test "does not add custom Cache-Control header when option is nil" do
      feed = minimal_feed()
      opts = Plug.init(feed_fn: fn _conn -> feed end)
      conn = conn(:get, "/feed") |> Plug.call(opts)

      refute "public, max-age=900" in get_resp_header(conn, "cache-control")
    end
  end

  describe "content type" do
    test "uses default content type" do
      feed = minimal_feed()
      opts = Plug.init(feed_fn: fn _conn -> feed end)
      conn = conn(:get, "/feed") |> Plug.call(opts)

      assert get_resp_header(conn, "content-type") |> hd() =~ "application/rss+xml"
    end

    test "allows custom content type" do
      feed = minimal_feed()
      opts = Plug.init(feed_fn: fn _conn -> feed end, content_type: "application/xml")
      conn = conn(:get, "/feed") |> Plug.call(opts)

      assert get_resp_header(conn, "content-type") |> hd() =~ "application/xml"
    end
  end

  describe "conn halting" do
    test "halts the conn after a successful response" do
      feed = minimal_feed()
      opts = Plug.init(feed_fn: fn _conn -> feed end)
      conn = conn(:get, "/feed") |> Plug.call(opts)

      assert conn.halted
    end

    test "halts the conn on 404" do
      opts = Plug.init(feed_fn: fn _conn -> {:error, :not_found} end)
      conn = conn(:get, "/feed") |> Plug.call(opts)

      assert conn.halted
    end

    test "halts the conn on 500 from feed_fn" do
      opts = Plug.init(feed_fn: fn _conn -> {:error, :boom} end)
      conn = conn(:get, "/feed") |> Plug.call(opts)

      assert conn.halted
    end

    test "halts the conn on 500 from generate failure" do
      invalid_feed = %Feed{title: "", link: "https://example.com", description: "desc"}
      opts = Plug.init(feed_fn: fn _conn -> invalid_feed end)
      conn = conn(:get, "/feed") |> Plug.call(opts)

      assert conn.halted
    end
  end

  describe "content-type charset" do
    test "does not duplicate charset in default content type" do
      feed = minimal_feed()
      opts = Plug.init(feed_fn: fn _conn -> feed end)
      conn = conn(:get, "/feed") |> Plug.call(opts)

      [content_type] = get_resp_header(conn, "content-type")
      # Should contain charset exactly once
      assert length(String.split(content_type, "charset=utf-8") -- [""]) <= 1
    end

    test "preserves charset from custom content type" do
      feed = minimal_feed()

      opts =
        Plug.init(
          feed_fn: fn _conn -> feed end,
          content_type: "application/atom+xml; charset=utf-8"
        )

      conn = conn(:get, "/feed") |> Plug.call(opts)

      [content_type] = get_resp_header(conn, "content-type")
      assert content_type == "application/atom+xml; charset=utf-8"
    end
  end

  describe "conn passthrough" do
    test "feed_fn receives the actual conn with path info" do
      opts =
        Plug.init(
          feed_fn: fn conn ->
            assert conn.path_info == ["feeds", "123"]
            minimal_feed()
          end
        )

      conn = conn(:get, "/feeds/123") |> Plug.call(opts)
      assert conn.status == 200
    end

    test "feed_fn receives the actual conn with query params" do
      opts =
        Plug.init(
          feed_fn: fn conn ->
            assert conn.query_string == "page=2"
            minimal_feed()
          end
        )

      conn = conn(:get, "/feed?page=2") |> Plug.call(opts)
      assert conn.status == 200
    end
  end
end
