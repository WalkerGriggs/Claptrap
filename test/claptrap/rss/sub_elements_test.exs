defmodule Claptrap.RSS.SubElementsTest do
  use ExUnit.Case, async: true

  alias Claptrap.RSS.Category
  alias Claptrap.RSS.Cloud
  alias Claptrap.RSS.Enclosure
  alias Claptrap.RSS.Guid
  alias Claptrap.RSS.Image
  alias Claptrap.RSS.Source
  alias Claptrap.RSS.TextInput

  describe "Category" do
    test "enforces :value" do
      assert_raise ArgumentError, fn -> struct!(Category, %{}) end
    end

    test "accepts all fields" do
      cat = %Category{value: "Tech", domain: "http://example.com/categories"}
      assert cat.value == "Tech"
      assert cat.domain == "http://example.com/categories"
    end

    test "domain defaults to nil" do
      cat = %Category{value: "News"}
      assert cat.domain == nil
    end
  end

  describe "Cloud" do
    test "enforces all required keys" do
      assert_raise ArgumentError, fn -> struct!(Cloud, %{}) end
      assert_raise ArgumentError, fn -> struct!(Cloud, %{domain: "example.com"}) end
    end

    test "accepts all fields" do
      cloud = %Cloud{
        domain: "rpc.example.com",
        port: 80,
        path: "/RPC2",
        register_procedure: "myCloud.rssPleaseNotify",
        protocol: "xml-rpc"
      }

      assert cloud.domain == "rpc.example.com"
      assert cloud.port == 80
      assert cloud.path == "/RPC2"
      assert cloud.register_procedure == "myCloud.rssPleaseNotify"
      assert cloud.protocol == "xml-rpc"
    end
  end

  describe "Image" do
    test "enforces :url, :title, :link" do
      assert_raise ArgumentError, fn -> struct!(Image, %{}) end
      assert_raise ArgumentError, fn -> struct!(Image, %{url: "http://example.com/img.png"}) end
    end

    test "accepts all fields" do
      image = %Image{
        url: "http://example.com/img.png",
        title: "Example",
        link: "http://example.com",
        width: 88,
        height: 31,
        description: "An example image"
      }

      assert image.url == "http://example.com/img.png"
      assert image.width == 88
      assert image.height == 31
      assert image.description == "An example image"
    end

    test "optional fields default to nil" do
      image = %Image{url: "http://example.com/img.png", title: "Ex", link: "http://example.com"}
      assert image.width == nil
      assert image.height == nil
      assert image.description == nil
    end
  end

  describe "TextInput" do
    test "enforces all required keys" do
      assert_raise ArgumentError, fn -> struct!(TextInput, %{}) end
    end

    test "accepts all fields" do
      ti = %TextInput{
        title: "Search",
        description: "Search this site",
        name: "q",
        link: "http://example.com/search"
      }

      assert ti.title == "Search"
      assert ti.description == "Search this site"
      assert ti.name == "q"
      assert ti.link == "http://example.com/search"
    end
  end

  describe "Enclosure" do
    test "enforces :url, :length, :type" do
      assert_raise ArgumentError, fn -> struct!(Enclosure, %{}) end
    end

    test "accepts all fields" do
      enc = %Enclosure{
        url: "http://example.com/episode.mp3",
        length: 12_216_320,
        type: "audio/mpeg"
      }

      assert enc.url == "http://example.com/episode.mp3"
      assert enc.length == 12_216_320
      assert enc.type == "audio/mpeg"
    end
  end

  describe "Guid" do
    test "enforces :value" do
      assert_raise ArgumentError, fn -> struct!(Guid, %{}) end
    end

    test "is_perma_link defaults to true" do
      guid = %Guid{value: "http://example.com/item/1"}
      assert guid.is_perma_link == true
    end

    test "accepts all fields" do
      guid = %Guid{value: "abc-123", is_perma_link: false}
      assert guid.value == "abc-123"
      assert guid.is_perma_link == false
    end
  end

  describe "Source" do
    test "enforces :value and :url" do
      assert_raise ArgumentError, fn -> struct!(Source, %{}) end
      assert_raise ArgumentError, fn -> struct!(Source, %{value: "News"}) end
    end

    test "accepts all fields" do
      src = %Source{value: "Tomalak's Realm", url: "http://www.tomalak.org/links2.xml"}
      assert src.value == "Tomalak's Realm"
      assert src.url == "http://www.tomalak.org/links2.xml"
    end
  end
end
