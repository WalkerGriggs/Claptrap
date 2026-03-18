defmodule Claptrap.RSS.FeedTest do
  use ExUnit.Case, async: true

  alias Claptrap.RSS.Feed

  @required_attrs %{
    title: "Test Channel",
    link: "https://example.com",
    description: "A test RSS channel"
  }

  describe "struct creation" do
    test "creating a feed with required fields succeeds" do
      feed = struct!(Feed, @required_attrs)

      assert feed.title == "Test Channel"
      assert feed.link == "https://example.com"
      assert feed.description == "A test RSS channel"
    end

    test "creating a feed without :title raises ArgumentError" do
      assert_raise ArgumentError, fn ->
        struct!(Feed, Map.delete(@required_attrs, :title))
      end
    end

    test "creating a feed without :link raises ArgumentError" do
      assert_raise ArgumentError, fn ->
        struct!(Feed, Map.delete(@required_attrs, :link))
      end
    end

    test "creating a feed without :description raises ArgumentError" do
      assert_raise ArgumentError, fn ->
        struct!(Feed, Map.delete(@required_attrs, :description))
      end
    end

    test "optional scalar fields default to nil" do
      feed = struct!(Feed, @required_attrs)

      assert feed.language == nil
      assert feed.copyright == nil
      assert feed.managing_editor == nil
      assert feed.web_master == nil
      assert feed.pub_date == nil
      assert feed.last_build_date == nil
      assert feed.generator == nil
      assert feed.docs == nil
      assert feed.ttl == nil
      assert feed.rating == nil
      assert feed.image == nil
      assert feed.text_input == nil
      assert feed.cloud == nil
    end

    test "list fields default to empty lists" do
      feed = struct!(Feed, @required_attrs)

      assert feed.categories == []
      assert feed.skip_hours == []
      assert feed.skip_days == []
      assert feed.items == []
    end

    test "map fields default to empty maps" do
      feed = struct!(Feed, @required_attrs)

      assert feed.namespaces == %{}
      assert feed.extensions == %{}
    end

    test "full struct with all fields populated" do
      now = DateTime.utc_now()

      attrs =
        Map.merge(@required_attrs, %{
          language: "en-us",
          copyright: "Copyright 2025",
          managing_editor: "editor@example.com",
          web_master: "webmaster@example.com",
          pub_date: now,
          last_build_date: now,
          generator: "Claptrap RSS",
          docs: "https://www.rssboard.org/rss-specification",
          ttl: 60,
          rating: "PG",
          image: %{url: "https://example.com/image.png", title: "Logo", link: "https://example.com"},
          text_input: %{title: "Search", description: "Search this feed", name: "q", link: "https://example.com/search"},
          cloud: %{domain: "example.com", port: 80, path: "/rpc", register_procedure: "notify", protocol: "xml-rpc"},
          categories: [%{domain: "https://example.com/cats", value: "Tech"}],
          skip_hours: [0, 6, 12, 18],
          skip_days: ["Saturday", "Sunday"],
          items: [%{title: "Item 1", link: "https://example.com/1"}],
          namespaces: %{"dc" => "http://purl.org/dc/elements/1.1/"},
          extensions: %{"http://purl.org/dc/elements/1.1/" => [%{name: "creator", attrs: %{}, value: "Author"}]}
        })

      feed = struct!(Feed, attrs)

      assert feed.language == "en-us"
      assert feed.copyright == "Copyright 2025"
      assert feed.managing_editor == "editor@example.com"
      assert feed.web_master == "webmaster@example.com"
      assert feed.pub_date == now
      assert feed.last_build_date == now
      assert feed.generator == "Claptrap RSS"
      assert feed.docs == "https://www.rssboard.org/rss-specification"
      assert feed.ttl == 60
      assert feed.rating == "PG"
      assert feed.image != nil
      assert feed.text_input != nil
      assert feed.cloud != nil
      assert length(feed.categories) == 1
      assert feed.skip_hours == [0, 6, 12, 18]
      assert feed.skip_days == ["Saturday", "Sunday"]
      assert length(feed.items) == 1
      assert feed.namespaces == %{"dc" => "http://purl.org/dc/elements/1.1/"}
      assert map_size(feed.extensions) == 1
    end
  end
end
