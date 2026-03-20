defmodule Claptrap.RSS.GeneratorTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Claptrap.RSS.{
    Category,
    Cloud,
    Enclosure,
    Feed,
    GenerateError,
    Generator,
    Guid,
    Image,
    Item,
    Source,
    TextInput
  }

  # -- Helpers -----------------------------------------------------------

  defp minimal_feed do
    Feed.new("Test Channel", "https://example.com", "A test feed")
  end

  defp parse_xml(xml) do
    xml
    |> String.to_charlist()
    |> :xmerl_scan.string(quiet: true)
  end

  defp xpath(xml_string, path) do
    {doc, _} = parse_xml(xml_string)

    :xmerl_xpath.string(String.to_charlist(path), doc)
  end

  defp xpath_text(xml_string, path) do
    case xpath(xml_string, path) do
      [{:xmlElement, _, _, _, _, _, _, _, children, _, _, _} | _] ->
        Enum.map_join(children, "", fn
          {:xmlText, _, _, _, value, _} -> to_string(value)
          _ -> ""
        end)

      _ ->
        nil
    end
  end

  defp xpath_attr(xml_string, element_path, attr_name) do
    case xpath(xml_string, element_path) do
      [{:xmlElement, _, _, _, _, _, _, attrs, _, _, _, _} | _] ->
        find_attr(attrs, attr_name)

      _ ->
        nil
    end
  end

  defp find_attr(attrs, attr_name) do
    Enum.find_value(attrs, fn
      {:xmlAttribute, name, _, _, _, _, _, _, value, _} ->
        if to_string(name) == attr_name, do: to_string(value)

      _ ->
        nil
    end)
  end

  defp fixed_datetime do
    ~U[2024-06-15 12:30:00Z]
  end

  # -- Minimal feed ------------------------------------------------------

  describe "minimal valid feed" do
    test "produces valid XML with declaration and rss/channel wrappers" do
      assert {:ok, xml} = Generator.generate(minimal_feed())
      assert String.starts_with?(xml, ~s(<?xml version="1.0" encoding="UTF-8"?>))
      assert xml =~ ~s(<rss version="2.0">)
      assert xml =~ "<channel>"
      assert xml =~ "</channel>"
      assert xml =~ "</rss>"
    end

    test "includes required channel elements" do
      assert {:ok, xml} = Generator.generate(minimal_feed())
      assert xpath_text(xml, "/rss/channel/title") == "Test Channel"
      assert xpath_text(xml, "/rss/channel/link") == "https://example.com"
      assert xpath_text(xml, "/rss/channel/description") == "A test feed"
    end

    test "output is parseable by :xmerl" do
      assert {:ok, xml} = Generator.generate(minimal_feed())
      assert {_doc, _rest} = parse_xml(xml)
    end
  end

  # -- Optional channel elements -----------------------------------------

  describe "optional channel elements" do
    test "language appears when set" do
      feed = Feed.put_language(minimal_feed(), "en-us")
      assert {:ok, xml} = Generator.generate(feed)
      assert xpath_text(xml, "/rss/channel/language") == "en-us"
    end

    test "copyright appears when set" do
      feed = Feed.put_copyright(minimal_feed(), "2024 Example Corp")
      assert {:ok, xml} = Generator.generate(feed)
      assert xpath_text(xml, "/rss/channel/copyright") == "2024 Example Corp"
    end

    test "managingEditor appears when set" do
      feed = Feed.put_managing_editor(minimal_feed(), "editor@example.com")
      assert {:ok, xml} = Generator.generate(feed)
      assert xpath_text(xml, "/rss/channel/managingEditor") == "editor@example.com"
    end

    test "webMaster appears when set" do
      feed = Feed.put_web_master(minimal_feed(), "webmaster@example.com")
      assert {:ok, xml} = Generator.generate(feed)
      assert xpath_text(xml, "/rss/channel/webMaster") == "webmaster@example.com"
    end

    test "generator appears when set" do
      feed = Feed.put_generator(minimal_feed(), "Claptrap v0.1")
      assert {:ok, xml} = Generator.generate(feed)
      assert xpath_text(xml, "/rss/channel/generator") == "Claptrap v0.1"
    end

    test "docs appears when set" do
      feed = Feed.put_docs(minimal_feed(), "https://www.rssboard.org/rss-specification")
      assert {:ok, xml} = Generator.generate(feed)
      assert xpath_text(xml, "/rss/channel/docs") == "https://www.rssboard.org/rss-specification"
    end

    test "ttl appears when set" do
      feed = Feed.put_ttl(minimal_feed(), 60)
      assert {:ok, xml} = Generator.generate(feed)
      assert xpath_text(xml, "/rss/channel/ttl") == "60"
    end

    test "pubDate formatted as RFC 822" do
      feed = Feed.put_pub_date(minimal_feed(), fixed_datetime())
      assert {:ok, xml} = Generator.generate(feed)
      pub_date = xpath_text(xml, "/rss/channel/pubDate")
      assert pub_date =~ "Sat, 15 Jun 2024"
      assert pub_date =~ "+0000"
    end

    test "lastBuildDate formatted as RFC 822" do
      feed = Feed.put_last_build_date(minimal_feed(), fixed_datetime())
      assert {:ok, xml} = Generator.generate(feed)
      lbd = xpath_text(xml, "/rss/channel/lastBuildDate")
      assert lbd =~ "Sat, 15 Jun 2024"
    end

    test "all optional elements present when populated" do
      feed =
        minimal_feed()
        |> Feed.put_language("en-us")
        |> Feed.put_copyright("2024")
        |> Feed.put_managing_editor("ed@example.com")
        |> Feed.put_web_master("wm@example.com")
        |> Feed.put_pub_date(fixed_datetime())
        |> Feed.put_last_build_date(fixed_datetime())
        |> Feed.put_generator("Claptrap")
        |> Feed.put_docs("https://example.com/docs")
        |> Feed.put_ttl(30)

      assert {:ok, xml} = Generator.generate(feed)
      assert {_doc, _} = parse_xml(xml)
      assert xpath_text(xml, "/rss/channel/language") == "en-us"
      assert xpath_text(xml, "/rss/channel/ttl") == "30"
    end
  end

  # -- Items -------------------------------------------------------------

  describe "item generation" do
    test "item with all fields generates correctly" do
      item =
        Item.new(title: "Item Title")
        |> Item.put_link("https://example.com/item1")
        |> Item.put_description("Item description")
        |> Item.put_author("author@example.com")
        |> Item.put_comments("https://example.com/item1/comments")
        |> Item.put_pub_date(fixed_datetime())

      feed = Feed.add_item(minimal_feed(), item)
      assert {:ok, xml} = Generator.generate(feed)
      assert xpath_text(xml, "/rss/channel/item/title") == "Item Title"
      assert xpath_text(xml, "/rss/channel/item/link") == "https://example.com/item1"
      assert xpath_text(xml, "/rss/channel/item/author") == "author@example.com"
      assert xpath_text(xml, "/rss/channel/item/comments") == "https://example.com/item1/comments"
    end

    test "empty items list produces channel with no items" do
      assert {:ok, xml} = Generator.generate(minimal_feed())
      assert xpath(xml, "/rss/channel/item") == []
    end

    test "multiple items are emitted in order" do
      feed =
        minimal_feed()
        |> Feed.add_item(Item.new(title: "First"))
        |> Feed.add_item(Item.new(title: "Second"))
        |> Feed.add_item(Item.new(title: "Third"))

      assert {:ok, xml} = Generator.generate(feed)

      items = xpath(xml, "/rss/channel/item/title")

      titles =
        Enum.map(items, fn {:xmlElement, _, _, _, _, _, _, _, children, _, _, _} ->
          Enum.map_join(children, "", fn {:xmlText, _, _, _, v, _} -> to_string(v) end)
        end)

      assert titles == ["First", "Second", "Third"]
    end
  end

  # -- CDATA wrapping ----------------------------------------------------

  describe "CDATA wrapping" do
    test "description with HTML produces CDATA" do
      feed = %{minimal_feed() | description: "<p>Hello <b>world</b></p>"}
      assert {:ok, xml} = Generator.generate(feed, validate: false)
      assert xml =~ "<![CDATA[<p>Hello <b>world</b></p>]]>"
    end

    test "description with & produces CDATA" do
      feed = %{minimal_feed() | description: "Tom & Jerry"}
      assert {:ok, xml} = Generator.generate(feed, validate: false)
      assert xml =~ "<![CDATA[Tom & Jerry]]>"
    end

    test "description without special chars produces plain text (no CDATA)" do
      assert {:ok, xml} = Generator.generate(minimal_feed())
      refute xml =~ "CDATA"
      assert xml =~ "<description>A test feed</description>"
    end

    test "item description with HTML uses CDATA" do
      item = Item.new(title: "T") |> Item.put_description("<em>Important</em>")
      feed = Feed.add_item(minimal_feed(), item)
      assert {:ok, xml} = Generator.generate(feed)
      assert xml =~ "<![CDATA[<em>Important</em>]]>"
    end

    test "description containing ]]> falls back to XML escaping instead of CDATA" do
      desc = "<script>evil]]>more</script>"
      feed = %{minimal_feed() | description: desc}
      assert {:ok, xml} = Generator.generate(feed, validate: false)
      refute xml =~ "<![CDATA["
      assert xml =~ "&lt;script&gt;"
      {_doc, _} = xml |> String.to_charlist() |> :xmerl_scan.string(quiet: true)
    end

    test "item description without special chars is plain" do
      item = Item.new(title: "T") |> Item.put_description("plain text")
      feed = Feed.add_item(minimal_feed(), item)
      assert {:ok, xml} = Generator.generate(feed)
      assert xml =~ "<description>plain text</description>"
    end
  end

  # -- Enclosure ---------------------------------------------------------

  describe "enclosure element" do
    test "emits as self-closing element with attributes" do
      enc = %Enclosure{url: "https://example.com/ep.mp3", length: 12_216_320, type: "audio/mpeg"}
      item = Item.new(title: "T") |> Item.put_enclosure(enc)
      feed = Feed.add_item(minimal_feed(), item)
      assert {:ok, xml} = Generator.generate(feed)

      assert xml =~ ~s(url="https://example.com/ep.mp3")
      assert xml =~ ~s(length="12216320")
      assert xml =~ ~s(type="audio/mpeg")
      assert xml =~ ~s(/>)
    end
  end

  # -- Cloud -------------------------------------------------------------

  describe "cloud element" do
    test "emits as self-closing element with all attributes" do
      cloud = %Cloud{
        domain: "rpc.example.com",
        port: 80,
        path: "/RPC2",
        register_procedure: "notify",
        protocol: "xml-rpc"
      }

      feed = Feed.put_cloud(minimal_feed(), cloud)
      assert {:ok, xml} = Generator.generate(feed)
      assert xml =~ ~s(domain="rpc.example.com")
      assert xml =~ ~s(port="80")
      assert xml =~ ~s(path="/RPC2")
      assert xml =~ ~s(registerProcedure="notify")
      assert xml =~ ~s(protocol="xml-rpc")
      assert xml =~ ~r/<cloud[^>]*\/>/
    end
  end

  # -- Guid --------------------------------------------------------------

  describe "guid element" do
    test "emits with isPermaLink=\"true\" by default" do
      guid = %Guid{value: "https://example.com/123", is_perma_link: true}
      item = Item.new(title: "T") |> Item.put_guid(guid)
      feed = Feed.add_item(minimal_feed(), item)
      assert {:ok, xml} = Generator.generate(feed)
      assert xml =~ ~s(isPermaLink="true")
      assert xpath_text(xml, "/rss/channel/item/guid") == "https://example.com/123"
    end

    test "emits with isPermaLink=\"false\" when set" do
      guid = %Guid{value: "unique-id-456", is_perma_link: false}
      item = Item.new(title: "T") |> Item.put_guid(guid)
      feed = Feed.add_item(minimal_feed(), item)
      assert {:ok, xml} = Generator.generate(feed)
      assert xml =~ ~s(isPermaLink="false")
      assert xpath_text(xml, "/rss/channel/item/guid") == "unique-id-456"
    end
  end

  # -- Source ------------------------------------------------------------

  describe "source element" do
    test "emits with url attribute and text content" do
      src = %Source{value: "Other Feed", url: "https://other.com/rss"}
      item = Item.new(title: "T") |> Item.put_source(src)
      feed = Feed.add_item(minimal_feed(), item)
      assert {:ok, xml} = Generator.generate(feed)

      assert xpath_text(xml, "/rss/channel/item/source") == "Other Feed"
      assert xpath_attr(xml, "/rss/channel/item/source", "url") == "https://other.com/rss"
    end
  end

  # -- Categories --------------------------------------------------------

  describe "categories" do
    test "channel-level categories emit correctly" do
      feed =
        minimal_feed()
        |> Feed.add_category(%Category{value: "Tech"})
        |> Feed.add_category(%Category{value: "News", domain: "https://example.com/cats"})

      assert {:ok, xml} = Generator.generate(feed)
      assert xml =~ "<category>Tech</category>"
      assert xml =~ ~s(category domain="https://example.com/cats">News</category>)
    end

    test "item-level categories emit correctly" do
      item =
        Item.new(title: "T")
        |> Item.add_category(%Category{value: "Elixir"})

      feed = Feed.add_item(minimal_feed(), item)
      assert {:ok, xml} = Generator.generate(feed)

      categories = xpath(xml, "/rss/channel/item/category")
      assert length(categories) == 1
    end
  end

  # -- Image -------------------------------------------------------------

  describe "image element" do
    test "emits sub-elements correctly" do
      img = %Image{
        url: "https://example.com/logo.png",
        title: "Logo",
        link: "https://example.com",
        width: 88,
        height: 31,
        description: "Site logo"
      }

      feed = Feed.put_image(minimal_feed(), img)
      assert {:ok, xml} = Generator.generate(feed)
      assert xpath_text(xml, "/rss/channel/image/url") == "https://example.com/logo.png"
      assert xpath_text(xml, "/rss/channel/image/title") == "Logo"
      assert xpath_text(xml, "/rss/channel/image/link") == "https://example.com"
      assert xpath_text(xml, "/rss/channel/image/width") == "88"
      assert xpath_text(xml, "/rss/channel/image/height") == "31"
      assert xpath_text(xml, "/rss/channel/image/description") == "Site logo"
    end
  end

  # -- TextInput ---------------------------------------------------------

  describe "textInput element" do
    test "emits all sub-elements" do
      ti = %TextInput{
        title: "Search",
        description: "Search this site",
        name: "q",
        link: "https://example.com/search"
      }

      feed = Feed.put_text_input(minimal_feed(), ti)
      assert {:ok, xml} = Generator.generate(feed)
      assert xpath_text(xml, "/rss/channel/textInput/title") == "Search"
      assert xpath_text(xml, "/rss/channel/textInput/name") == "q"
    end
  end

  # -- Skip hours / days -------------------------------------------------

  describe "skipHours and skipDays" do
    test "skipHours emits hour sub-elements" do
      feed = %{minimal_feed() | skip_hours: [0, 12, 23]}
      assert {:ok, xml} = Generator.generate(feed, validate: false)
      assert xml =~ "<skipHours>"
      assert xml =~ "<hour>0</hour>"
      assert xml =~ "<hour>12</hour>"
      assert xml =~ "<hour>23</hour>"
    end

    test "skipDays emits day sub-elements" do
      feed = %{minimal_feed() | skip_days: ["Saturday", "Sunday"]}
      assert {:ok, xml} = Generator.generate(feed, validate: false)
      assert xml =~ "<skipDays>"
      assert xml =~ "<day>Saturday</day>"
      assert xml =~ "<day>Sunday</day>"
    end
  end

  # -- Namespaces --------------------------------------------------------

  describe "namespace declarations" do
    test "declared on rss element" do
      feed = Feed.put_namespace(minimal_feed(), "dc", "http://purl.org/dc/elements/1.1/")
      assert {:ok, xml} = Generator.generate(feed)
      assert xml =~ ~s(xmlns:dc="http://purl.org/dc/elements/1.1/")
      assert xml =~ ~s(<rss version="2.0")
    end

    test "multiple namespaces declared" do
      feed =
        minimal_feed()
        |> Feed.put_namespace("dc", "http://purl.org/dc/elements/1.1/")
        |> Feed.put_namespace("content", "http://purl.org/rss/1.0/modules/content/")

      assert {:ok, xml} = Generator.generate(feed)
      assert xml =~ ~s(xmlns:dc=)
      assert xml =~ ~s(xmlns:content=)
    end
  end

  # -- Extensions --------------------------------------------------------

  describe "extension elements" do
    test "emitted with correct prefixes" do
      dc_uri = "http://purl.org/dc/elements/1.1/"

      feed =
        minimal_feed()
        |> Feed.put_namespace("dc", dc_uri)
        |> Feed.add_extension(dc_uri, %{name: "creator", attrs: %{}, value: "John Doe"})

      assert {:ok, xml} = Generator.generate(feed)
      assert xml =~ "<dc:creator>John Doe</dc:creator>"
    end

    test "nested extension elements" do
      media_uri = "http://search.yahoo.com/mrss/"

      child = %{name: "content", attrs: %{"url" => "https://example.com/video.mp4", "type" => "video/mp4"}, value: ""}
      group = %{name: "group", attrs: %{}, value: [child]}

      feed =
        minimal_feed()
        |> Feed.put_namespace("media", media_uri)
        |> Feed.add_extension(media_uri, group)

      assert {:ok, xml} = Generator.generate(feed)
      assert xml =~ "<media:group>"
      assert xml =~ "media:content"
      assert xml =~ ~s(url="https://example.com/video.mp4")
      assert xml =~ "</media:group>"
    end

    test "item extension elements emitted" do
      dc_uri = "http://purl.org/dc/elements/1.1/"

      item =
        Item.new(title: "T")
        |> Item.add_extension(dc_uri, %{name: "creator", attrs: %{}, value: "Jane Smith"})

      feed =
        minimal_feed()
        |> Feed.put_namespace("dc", dc_uri)
        |> Feed.add_item(item)

      assert {:ok, xml} = Generator.generate(feed)
      assert xml =~ "<dc:creator>Jane Smith</dc:creator>"
    end
  end

  # -- Validation option -------------------------------------------------

  describe "validate option" do
    test "validate: false skips validation" do
      bad_feed = %{minimal_feed() | title: ""}
      assert {:ok, xml} = Generator.generate(bad_feed, validate: false)
      assert is_binary(xml)
    end

    test "validate: true (default) returns GenerateError for invalid feeds" do
      bad_feed = %{minimal_feed() | title: ""}
      assert {:error, %GenerateError{reason: :validation_failed}} = Generator.generate(bad_feed)
    end

    test "validate: true with valid feed succeeds" do
      assert {:ok, _xml} = Generator.generate(minimal_feed(), validate: true)
    end
  end

  # -- Custom date module ------------------------------------------------

  describe "custom date_module option" do
    defmodule StubDate do
      @behaviour Claptrap.RSS.DateBehaviour

      @impl true
      def parse(_), do: {:error, :invalid_date}

      @impl true
      def format(_), do: "STUB_DATE"
    end

    test "uses custom date module for formatting" do
      feed = Feed.put_pub_date(minimal_feed(), fixed_datetime())
      assert {:ok, xml} = Generator.generate(feed, date_module: StubDate)
      assert xml =~ "STUB_DATE"
    end
  end

  # -- XML escaping ------------------------------------------------------

  describe "XML escaping" do
    test "special characters in title are escaped" do
      feed = %{minimal_feed() | title: "Tom & Jerry's <Show>"}
      assert {:ok, xml} = Generator.generate(feed, validate: false)
      assert xml =~ "Tom &amp; Jerry&apos;s &lt;Show&gt;"
    end
  end

  # -- Round-trip parseable by xmerl -------------------------------------

  describe "round-trip XML validity" do
    test "fully populated feed is parseable by xmerl" do
      cloud = %Cloud{
        domain: "rpc.example.com",
        port: 80,
        path: "/RPC2",
        register_procedure: "notify",
        protocol: "xml-rpc"
      }

      img = %Image{
        url: "https://example.com/logo.png",
        title: "Logo",
        link: "https://example.com"
      }

      ti = %TextInput{
        title: "Search",
        description: "Search this site",
        name: "q",
        link: "https://example.com/search"
      }

      enc = %Enclosure{url: "https://example.com/ep.mp3", length: 12_216_320, type: "audio/mpeg"}
      guid = %Guid{value: "https://example.com/1", is_perma_link: true}
      src = %Source{value: "Other Feed", url: "https://other.com/rss"}

      item =
        Item.new(title: "Item 1")
        |> Item.put_link("https://example.com/1")
        |> Item.put_description("A description")
        |> Item.put_author("author@example.com")
        |> Item.put_comments("https://example.com/1/comments")
        |> Item.put_pub_date(fixed_datetime())
        |> Item.put_enclosure(enc)
        |> Item.put_guid(guid)
        |> Item.put_source(src)
        |> Item.add_category(%Category{value: "Elixir"})
        |> Item.add_category(%Category{value: "Tech", domain: "https://example.com/cats"})

      feed =
        minimal_feed()
        |> Feed.put_language("en-us")
        |> Feed.put_copyright("2024 Example")
        |> Feed.put_managing_editor("editor@example.com")
        |> Feed.put_web_master("webmaster@example.com")
        |> Feed.put_pub_date(fixed_datetime())
        |> Feed.put_last_build_date(fixed_datetime())
        |> Feed.put_generator("Claptrap v0.1")
        |> Feed.put_docs("https://www.rssboard.org/rss-specification")
        |> Feed.put_ttl(60)
        |> Feed.put_cloud(cloud)
        |> Feed.put_image(img)
        |> Feed.put_text_input(ti)
        |> Feed.add_category(%Category{value: "Tech"})
        |> Feed.add_item(item)

      assert {:ok, xml} = Generator.generate(feed)
      assert {_doc, _rest} = parse_xml(xml)
    end
  end

  # -- Property tests ----------------------------------------------------

  describe "property tests" do
    property "generated XML is always parseable by :xmerl" do
      check all(feed <- valid_feed_gen()) do
        assert {:ok, xml} = Generator.generate(feed, validate: false)
        assert {_doc, _rest} = parse_xml(xml)
      end
    end

    property "generated XML always starts with XML declaration" do
      check all(feed <- valid_feed_gen()) do
        assert {:ok, xml} = Generator.generate(feed, validate: false)
        assert String.starts_with?(xml, ~s(<?xml version="1.0" encoding="UTF-8"?>))
      end
    end

    property "generated XML always contains rss and channel wrappers" do
      check all(feed <- valid_feed_gen()) do
        assert {:ok, xml} = Generator.generate(feed, validate: false)
        assert xml =~ "<rss"
        assert xml =~ "<channel>"
        assert xml =~ "</channel>"
        assert xml =~ "</rss>"
      end
    end

    property "channel title round-trips through generate and xmerl parse" do
      check all(
              title <- non_empty_alpha_gen(),
              desc <- non_empty_alpha_gen()
            ) do
        feed = Feed.new(title, "https://example.com", desc)
        assert {:ok, xml} = Generator.generate(feed)
        assert xpath_text(xml, "/rss/channel/title") == title
      end
    end

    property "item count in generated XML matches input" do
      check all(
              n <- integer(0..5),
              titles <- list_of(non_empty_alpha_gen(), length: n)
            ) do
        feed =
          Enum.reduce(titles, minimal_feed(), fn title, acc ->
            Feed.add_item(acc, Item.new(title: title))
          end)

        assert {:ok, xml} = Generator.generate(feed)
        items = xpath(xml, "/rss/channel/item")
        assert length(items) == n
      end
    end

    property "descriptions with < or & always use CDATA" do
      check all(
              prefix <- non_empty_alpha_gen(),
              special <- member_of(["<", "&"]),
              suffix <- non_empty_alpha_gen()
            ) do
        desc = prefix <> special <> suffix
        feed = %{minimal_feed() | description: desc}
        assert {:ok, xml} = Generator.generate(feed, validate: false)
        assert xml =~ "<![CDATA["
      end
    end

    property "descriptions without < or & never use CDATA" do
      check all(desc <- non_empty_alpha_gen()) do
        feed = Feed.new("Title", "https://example.com", desc)
        assert {:ok, xml} = Generator.generate(feed)
        refute xml =~ "CDATA"
      end
    end

    property "invalid feeds always return GenerateError with validate: true" do
      check all(feed <- invalid_feed_gen()) do
        assert {:error, %GenerateError{reason: :validation_failed}} = Generator.generate(feed)
      end
    end

    property "any feed generates successfully with validate: false" do
      check all(feed <- any_feed_gen()) do
        assert {:ok, xml} = Generator.generate(feed, validate: false)
        assert is_binary(xml)
      end
    end
  end

  # -- StreamData generators ---------------------------------------------

  defp valid_feed_gen do
    gen all(
          title <- non_empty_alpha_gen(),
          description <- non_empty_alpha_gen(),
          n <- integer(0..3),
          items <- list_of(valid_item_gen(), length: n)
        ) do
      %Feed{
        title: title,
        link: "https://example.com",
        description: description,
        items: items
      }
    end
  end

  defp valid_item_gen do
    gen all(title <- non_empty_alpha_gen()) do
      Item.new(title: title)
    end
  end

  defp invalid_feed_gen do
    gen all(feed <- valid_feed_gen()) do
      %{feed | title: ""}
    end
  end

  defp any_feed_gen do
    gen all(
          title <- one_of([constant(""), non_empty_alpha_gen()]),
          desc <- one_of([constant(""), non_empty_alpha_gen()])
        ) do
      %Feed{
        title: title,
        link: "https://example.com",
        description: desc
      }
    end
  end

  defp non_empty_alpha_gen do
    string(:alphanumeric, min_length: 1, max_length: 50)
  end
end
