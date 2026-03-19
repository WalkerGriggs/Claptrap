defmodule Claptrap.RSS.ItemTest do
  use ExUnit.Case, async: true

  alias Claptrap.RSS.Item

  describe "struct creation" do
    test "creates an item with no fields" do
      item = %Item{}
      assert %Item{} = item
    end

    test "creates an item with all fields populated" do
      now = DateTime.utc_now()

      item = %Item{
        title: "Example Item",
        link: "https://example.com/item",
        description: "<p>Item synopsis</p>",
        author: "author@example.com",
        comments: "https://example.com/item/comments",
        pub_date: now,
        enclosure: %{url: "https://example.com/audio.mp3", length: 12_345, type: "audio/mpeg"},
        guid: %{value: "unique-id-123", is_permalink: true},
        source: %{url: "https://example.com/feed.xml", name: "Example Feed"},
        categories: [%{domain: "http://example.com/cats", value: "Tech"}],
        extensions: %{"http://purl.org/dc/elements/1.1/" => [%{name: "creator", attrs: %{}, value: "Author"}]}
      }

      assert item.title == "Example Item"
      assert item.link == "https://example.com/item"
      assert item.description == "<p>Item synopsis</p>"
      assert item.author == "author@example.com"
      assert item.comments == "https://example.com/item/comments"
      assert item.pub_date == now
      assert item.enclosure == %{url: "https://example.com/audio.mp3", length: 12_345, type: "audio/mpeg"}
      assert item.guid == %{value: "unique-id-123", is_permalink: true}
      assert item.source == %{url: "https://example.com/feed.xml", name: "Example Feed"}
      assert length(item.categories) == 1
      assert map_size(item.extensions) == 1
    end

    test "default values are correct" do
      item = %Item{}

      assert item.title == nil
      assert item.link == nil
      assert item.description == nil
      assert item.author == nil
      assert item.comments == nil
      assert item.pub_date == nil
      assert item.enclosure == nil
      assert item.guid == nil
      assert item.source == nil
      assert item.categories == []
      assert item.extensions == %{}
    end

    test "categories defaults to an empty list" do
      item = %Item{title: "Test"}
      assert item.categories == []
    end

    test "extensions defaults to an empty map" do
      item = %Item{title: "Test"}
      assert item.extensions == %{}
    end
  end
end
