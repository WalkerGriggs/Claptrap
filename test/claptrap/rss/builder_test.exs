defmodule Claptrap.RSS.BuilderTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Claptrap.RSS.{Category, Cloud, Enclosure, Feed, Guid, Image, Item, Source, TextInput}

  @valid_days ~w(Monday Tuesday Wednesday Thursday Friday Saturday Sunday)

  # Returns the value opaquely so the type checker
  # cannot flag intentional type-mismatch tests.
  defp bad_arg(value),
    do: :erlang.binary_to_term(:erlang.term_to_binary(value))

  defp non_empty_string do
    StreamData.string(:alphanumeric, min_length: 1)
  end

  defp url_string do
    StreamData.map(non_empty_string(), &"https://example.com/#{&1}")
  end

  defp category_gen do
    gen all(
          value <- non_empty_string(),
          domain <- StreamData.one_of([StreamData.constant(nil), non_empty_string()])
        ) do
      %Category{value: value, domain: domain}
    end
  end

  defp datetime_gen do
    gen all(
          year <- StreamData.integer(2000..2030),
          month <- StreamData.integer(1..12),
          day <- StreamData.integer(1..28),
          hour <- StreamData.integer(0..23),
          minute <- StreamData.integer(0..59),
          second <- StreamData.integer(0..59)
        ) do
      {:ok, dt, _} =
        DateTime.from_iso8601("#{pad(year, 4)}-#{pad(month)}-#{pad(day)}T#{pad(hour)}:#{pad(minute)}:#{pad(second)}Z")

      dt
    end
  end

  defp pad(n, width \\ 2), do: n |> Integer.to_string() |> String.pad_leading(width, "0")

  defp base_feed, do: Feed.new("T", "https://example.com", "D")

  describe "Feed.new/3" do
    test "creates a feed with required fields and correct defaults" do
      assert Feed.new("Title", "https://example.com", "Description") == %Feed{
               title: "Title",
               link: "https://example.com",
               description: "Description",
               language: nil,
               copyright: nil,
               managing_editor: nil,
               web_master: nil,
               pub_date: nil,
               last_build_date: nil,
               generator: nil,
               docs: nil,
               ttl: nil,
               rating: nil,
               cloud: nil,
               image: nil,
               text_input: nil,
               categories: [],
               skip_hours: [],
               skip_days: [],
               items: [],
               namespaces: %{},
               extensions: %{}
             }
    end

    property "creates a feed for arbitrary non-empty strings" do
      check all(
              title <- non_empty_string(),
              link <- url_string(),
              desc <- non_empty_string()
            ) do
        assert Feed.new(title, link, desc) == %Feed{
                 title: title,
                 link: link,
                 description: desc,
                 language: nil,
                 copyright: nil,
                 managing_editor: nil,
                 web_master: nil,
                 pub_date: nil,
                 last_build_date: nil,
                 generator: nil,
                 docs: nil,
                 ttl: nil,
                 rating: nil,
                 cloud: nil,
                 image: nil,
                 text_input: nil,
                 categories: [],
                 skip_hours: [],
                 skip_days: [],
                 items: [],
                 namespaces: %{},
                 extensions: %{}
               }
      end
    end
  end

  describe "Feed put_* scalar setters" do
    test "put_language/2 sets language" do
      assert Feed.put_language(base_feed(), "en-us") == %Feed{
               title: "T",
               link: "https://example.com",
               description: "D",
               language: "en-us"
             }
    end

    test "put_copyright/2 sets copyright" do
      assert Feed.put_copyright(base_feed(), "2024 Acme") == %Feed{
               title: "T",
               link: "https://example.com",
               description: "D",
               copyright: "2024 Acme"
             }
    end

    test "put_managing_editor/2 sets managing_editor" do
      assert Feed.put_managing_editor(base_feed(), "ed@example.com") == %Feed{
               title: "T",
               link: "https://example.com",
               description: "D",
               managing_editor: "ed@example.com"
             }
    end

    test "put_web_master/2 sets web_master" do
      assert Feed.put_web_master(base_feed(), "wm@example.com") == %Feed{
               title: "T",
               link: "https://example.com",
               description: "D",
               web_master: "wm@example.com"
             }
    end

    test "put_pub_date/2 sets pub_date from DateTime" do
      dt = ~U[2024-01-15 10:30:00Z]

      assert Feed.put_pub_date(base_feed(), dt) == %Feed{
               title: "T",
               link: "https://example.com",
               description: "D",
               pub_date: dt
             }
    end

    test "put_last_build_date/2 sets last_build_date" do
      dt = ~U[2024-06-01 12:00:00Z]

      assert Feed.put_last_build_date(base_feed(), dt) == %Feed{
               title: "T",
               link: "https://example.com",
               description: "D",
               last_build_date: dt
             }
    end

    test "put_generator/2 sets generator" do
      assert Feed.put_generator(base_feed(), "Claptrap v1") == %Feed{
               title: "T",
               link: "https://example.com",
               description: "D",
               generator: "Claptrap v1"
             }
    end

    test "put_docs/2 sets docs URL" do
      url = "https://www.rssboard.org/rss-specification"

      assert Feed.put_docs(base_feed(), url) == %Feed{
               title: "T",
               link: "https://example.com",
               description: "D",
               docs: url
             }
    end

    test "put_ttl/2 accepts zero" do
      assert Feed.put_ttl(base_feed(), 0) == %Feed{
               title: "T",
               link: "https://example.com",
               description: "D",
               ttl: 0
             }
    end

    test "put_ttl/2 accepts positive integers" do
      assert Feed.put_ttl(base_feed(), 60) == %Feed{
               title: "T",
               link: "https://example.com",
               description: "D",
               ttl: 60
             }
    end

    test "put_ttl/2 rejects negative integers" do
      assert_raise FunctionClauseError, fn -> Feed.put_ttl(base_feed(), -1) end
    end

    test "put_ttl/2 rejects non-integers" do
      assert_raise FunctionClauseError, fn -> Feed.put_ttl(base_feed(), 1.5) end
    end

    property "scalar setters replace field values idempotently" do
      check all(
              title <- non_empty_string(),
              link <- url_string(),
              desc <- non_empty_string(),
              lang <- non_empty_string(),
              copyright <- non_empty_string(),
              generator <- non_empty_string(),
              ttl <- StreamData.integer(0..1440)
            ) do
        assert Feed.new(title, link, desc)
               |> Feed.put_language(lang)
               |> Feed.put_copyright(copyright)
               |> Feed.put_generator(generator)
               |> Feed.put_ttl(ttl) == %Feed{
                 title: title,
                 link: link,
                 description: desc,
                 language: lang,
                 copyright: copyright,
                 generator: generator,
                 ttl: ttl
               }
      end
    end

    property "put_pub_date/2 accepts arbitrary DateTimes" do
      check all(dt <- datetime_gen()) do
        assert Feed.put_pub_date(base_feed(), dt) == %Feed{
                 title: "T",
                 link: "https://example.com",
                 description: "D",
                 pub_date: dt
               }
      end
    end
  end

  describe "Feed put_* compound setters" do
    test "put_image/2 sets image" do
      image = %Image{url: "https://example.com/img.png", title: "Logo", link: "https://example.com"}

      assert Feed.put_image(base_feed(), image) == %Feed{
               title: "T",
               link: "https://example.com",
               description: "D",
               image: image
             }
    end

    test "put_text_input/2 sets text_input" do
      ti = %TextInput{
        title: "Search",
        description: "Search this feed",
        name: "q",
        link: "https://example.com/search"
      }

      assert Feed.put_text_input(base_feed(), ti) == %Feed{
               title: "T",
               link: "https://example.com",
               description: "D",
               text_input: ti
             }
    end

    test "put_cloud/2 sets cloud" do
      cloud = %Cloud{
        domain: "rpc.example.com",
        port: 80,
        path: "/RPC2",
        register_procedure: "notify",
        protocol: "xml-rpc"
      }

      assert Feed.put_cloud(base_feed(), cloud) == %Feed{
               title: "T",
               link: "https://example.com",
               description: "D",
               cloud: cloud
             }
    end

    test "put_image/2 rejects non-Image structs" do
      assert_raise FunctionClauseError, fn -> Feed.put_image(base_feed(), bad_arg(%{url: "x"})) end
    end

    test "put_cloud/2 rejects non-Cloud structs" do
      assert_raise FunctionClauseError, fn -> Feed.put_cloud(base_feed(), bad_arg(%{domain: "x"})) end
    end

    test "put_text_input/2 rejects non-TextInput structs" do
      assert_raise FunctionClauseError, fn -> Feed.put_text_input(base_feed(), bad_arg(%{title: "x"})) end
    end
  end

  describe "Feed add_* appenders" do
    test "add_item/2 appends items in order" do
      item1 = Item.new(title: "First")
      item2 = Item.new(title: "Second")

      assert base_feed()
             |> Feed.add_item(item1)
             |> Feed.add_item(item2) == %Feed{
               title: "T",
               link: "https://example.com",
               description: "D",
               items: [item1, item2]
             }
    end

    test "add_item/2 rejects non-Item structs" do
      assert_raise FunctionClauseError, fn -> Feed.add_item(base_feed(), bad_arg(%{title: "bad"})) end
    end

    test "add_category/2 appends categories in order" do
      cat1 = %Category{value: "tech"}
      cat2 = %Category{value: "news", domain: "https://example.com/cats"}

      assert base_feed()
             |> Feed.add_category(cat1)
             |> Feed.add_category(cat2) == %Feed{
               title: "T",
               link: "https://example.com",
               description: "D",
               categories: [cat1, cat2]
             }
    end

    test "add_skip_hour/2 with valid boundary hours" do
      assert base_feed()
             |> Feed.add_skip_hour(0)
             |> Feed.add_skip_hour(12)
             |> Feed.add_skip_hour(23) == %Feed{
               title: "T",
               link: "https://example.com",
               description: "D",
               skip_hours: [0, 12, 23]
             }
    end

    test "add_skip_hour/2 rejects hour 24" do
      assert_raise FunctionClauseError, fn -> Feed.add_skip_hour(base_feed(), 24) end
    end

    test "add_skip_hour/2 rejects negative hours" do
      assert_raise FunctionClauseError, fn -> Feed.add_skip_hour(base_feed(), -1) end
    end

    test "add_skip_day/2 with valid days" do
      assert base_feed()
             |> Feed.add_skip_day("Monday")
             |> Feed.add_skip_day("Friday") == %Feed{
               title: "T",
               link: "https://example.com",
               description: "D",
               skip_days: ["Monday", "Friday"]
             }
    end

    test "add_skip_day/2 rejects lowercase day names" do
      assert_raise FunctionClauseError, fn -> Feed.add_skip_day(base_feed(), "monday") end
    end

    test "add_skip_day/2 rejects invalid day names" do
      assert_raise FunctionClauseError, fn -> Feed.add_skip_day(base_feed(), "Holiday") end
    end

    property "add_item/2 preserves insertion order" do
      check all(titles <- StreamData.list_of(non_empty_string(), min_length: 1, max_length: 20)) do
        items = Enum.map(titles, &Item.new(title: &1))

        feed =
          Enum.reduce(items, base_feed(), fn item, acc ->
            Feed.add_item(acc, item)
          end)

        assert feed.items == items
      end
    end

    property "add_category/2 preserves insertion order" do
      check all(cats <- StreamData.list_of(category_gen(), min_length: 1, max_length: 10)) do
        feed =
          Enum.reduce(cats, base_feed(), fn cat, acc ->
            Feed.add_category(acc, cat)
          end)

        assert feed.categories == cats
      end
    end

    property "add_skip_hour/2 accepts all valid hours (0..23)" do
      check all(hour <- StreamData.integer(0..23)) do
        assert Feed.add_skip_hour(base_feed(), hour) == %Feed{
                 title: "T",
                 link: "https://example.com",
                 description: "D",
                 skip_hours: [hour]
               }
      end
    end

    property "add_skip_day/2 accepts all seven valid day names" do
      check all(day <- StreamData.member_of(@valid_days)) do
        assert Feed.add_skip_day(base_feed(), day) == %Feed{
                 title: "T",
                 link: "https://example.com",
                 description: "D",
                 skip_days: [day]
               }
      end
    end
  end

  describe "Feed namespace and extension helpers" do
    test "put_namespace/3 adds a namespace prefix mapping" do
      assert Feed.put_namespace(base_feed(), "dc", "http://purl.org/dc/elements/1.1/") == %Feed{
               title: "T",
               link: "https://example.com",
               description: "D",
               namespaces: %{"dc" => "http://purl.org/dc/elements/1.1/"}
             }
    end

    test "put_namespace/3 overwrites an existing prefix" do
      assert base_feed()
             |> Feed.put_namespace("dc", "http://old.example.com")
             |> Feed.put_namespace("dc", "http://purl.org/dc/elements/1.1/") == %Feed{
               title: "T",
               link: "https://example.com",
               description: "D",
               namespaces: %{"dc" => "http://purl.org/dc/elements/1.1/"}
             }
    end

    test "add_extension/3 appends elements under a namespace URI" do
      ns = "http://purl.org/dc/elements/1.1/"
      el1 = %{name: "creator", attrs: %{}, value: "Author A"}
      el2 = %{name: "creator", attrs: %{}, value: "Author B"}

      assert base_feed()
             |> Feed.add_extension(ns, el1)
             |> Feed.add_extension(ns, el2) == %Feed{
               title: "T",
               link: "https://example.com",
               description: "D",
               extensions: %{ns => [el1, el2]}
             }
    end

    test "add_extension/3 groups by namespace URI" do
      ns1 = "http://purl.org/dc/elements/1.1/"
      ns2 = "http://purl.org/rss/1.0/modules/content/"
      el1 = %{name: "creator", attrs: %{}, value: "Author"}
      el2 = %{name: "encoded", attrs: %{}, value: "<p>Hi</p>"}

      assert base_feed()
             |> Feed.add_extension(ns1, el1)
             |> Feed.add_extension(ns2, el2) == %Feed{
               title: "T",
               link: "https://example.com",
               description: "D",
               extensions: %{ns1 => [el1], ns2 => [el2]}
             }
    end

    test "add_extension/3 rejects non-map elements" do
      assert_raise FunctionClauseError, fn ->
        Feed.add_extension(base_feed(), "http://example.com/ns", "not a map")
      end
    end
  end

  describe "Item.new/0 and Item.new/1" do
    test "creates an empty item with no arguments" do
      assert Item.new() == %Item{
               title: nil,
               link: nil,
               description: nil,
               author: nil,
               comments: nil,
               enclosure: nil,
               guid: nil,
               pub_date: nil,
               source: nil,
               categories: [],
               extensions: %{}
             }
    end

    test "accepts keyword options" do
      assert Item.new(title: "Post", link: "https://example.com/1") == %Item{
               title: "Post",
               link: "https://example.com/1",
               description: nil,
               author: nil,
               comments: nil,
               enclosure: nil,
               guid: nil,
               pub_date: nil,
               source: nil,
               categories: [],
               extensions: %{}
             }
    end

    test "raises on unknown keys" do
      assert_raise KeyError, fn -> Item.new(bogus: "value") end
    end
  end

  describe "Item put_* setters" do
    test "put_title/2" do
      assert Item.put_title(Item.new(), "Title") == %Item{title: "Title"}
    end

    test "put_link/2" do
      assert Item.put_link(Item.new(), "https://example.com/1") == %Item{
               link: "https://example.com/1"
             }
    end

    test "put_description/2" do
      assert Item.put_description(Item.new(), "Hello") == %Item{description: "Hello"}
    end

    test "put_author/2" do
      assert Item.put_author(Item.new(), "author@example.com") == %Item{
               author: "author@example.com"
             }
    end

    test "put_comments/2" do
      assert Item.put_comments(Item.new(), "https://example.com/comments") == %Item{
               comments: "https://example.com/comments"
             }
    end

    test "put_pub_date/2 with DateTime" do
      dt = ~U[2024-03-15 08:00:00Z]
      assert Item.put_pub_date(Item.new(), dt) == %Item{pub_date: dt}
    end

    test "put_pub_date/2 rejects non-DateTime" do
      assert_raise FunctionClauseError, fn -> Item.put_pub_date(Item.new(), bad_arg("2024-01-01")) end
    end

    test "put_enclosure/2 with Enclosure struct" do
      enc = %Enclosure{url: "https://example.com/audio.mp3", length: 12_345_678, type: "audio/mpeg"}
      assert Item.put_enclosure(Item.new(), enc) == %Item{enclosure: enc}
    end

    test "put_enclosure/2 rejects non-Enclosure structs" do
      assert_raise FunctionClauseError, fn -> Item.put_enclosure(Item.new(), bad_arg(%{url: "x"})) end
    end

    test "put_guid/2 with Guid struct" do
      guid = %Guid{value: "unique-id-123"}
      assert Item.put_guid(Item.new(), guid) == %Item{guid: %Guid{value: "unique-id-123", is_perma_link: true}}
    end

    test "put_guid/2 with is_perma_link false" do
      guid = %Guid{value: "not-a-url", is_perma_link: false}
      assert Item.put_guid(Item.new(), guid) == %Item{guid: %Guid{value: "not-a-url", is_perma_link: false}}
    end

    test "put_source/2 with Source struct" do
      source = %Source{url: "https://other.com/rss", value: "Other Feed"}
      assert Item.put_source(Item.new(), source) == %Item{source: source}
    end

    property "put_* setters replace the field value" do
      check all(
              title <- non_empty_string(),
              link <- url_string(),
              desc <- non_empty_string(),
              author <- non_empty_string()
            ) do
        assert Item.new()
               |> Item.put_title(title)
               |> Item.put_link(link)
               |> Item.put_description(desc)
               |> Item.put_author(author) == %Item{
                 title: title,
                 link: link,
                 description: desc,
                 author: author
               }
      end
    end
  end

  describe "Item add_* appenders" do
    test "add_category/2 appends categories in order" do
      cat1 = %Category{value: "tech"}
      cat2 = %Category{value: "news"}

      assert Item.new()
             |> Item.add_category(cat1)
             |> Item.add_category(cat2) == %Item{categories: [cat1, cat2]}
    end

    test "add_category/2 rejects non-Category structs" do
      assert_raise FunctionClauseError, fn ->
        Item.add_category(Item.new(), bad_arg(%{value: "bad"}))
      end
    end

    test "add_extension/3 appends extension elements" do
      ns = "http://purl.org/rss/1.0/modules/content/"
      el = %{name: "encoded", attrs: %{}, value: "<p>Full HTML</p>"}

      assert Item.add_extension(Item.new(), ns, el) == %Item{extensions: %{ns => [el]}}
    end

    property "add_category/2 preserves insertion order" do
      check all(cats <- StreamData.list_of(category_gen(), min_length: 1, max_length: 10)) do
        item =
          Enum.reduce(cats, Item.new(), fn cat, acc ->
            Item.add_category(acc, cat)
          end)

        assert item.categories == cats
      end
    end
  end

  describe "Item pipeline" do
    property "pipeline builds complete items" do
      check all(
              title <- non_empty_string(),
              link <- url_string(),
              desc <- non_empty_string(),
              dt <- datetime_gen()
            ) do
        cat = %Category{value: "test"}

        assert Item.new()
               |> Item.put_title(title)
               |> Item.put_link(link)
               |> Item.put_description(desc)
               |> Item.put_pub_date(dt)
               |> Item.add_category(cat) == %Item{
                 title: title,
                 link: link,
                 description: desc,
                 pub_date: dt,
                 categories: [cat]
               }
      end
    end
  end

  describe "integration pipeline" do
    test "builds a complete feed with nested items via pipelines" do
      item =
        Item.new()
        |> Item.put_title("First Post")
        |> Item.put_link("https://example.com/1")
        |> Item.put_description("Hello world")
        |> Item.add_category(%Category{value: "tech"})

      assert Feed.new("My Feed", "https://example.com", "A test feed")
             |> Feed.put_language("en-us")
             |> Feed.put_ttl(60)
             |> Feed.add_item(item) == %Feed{
               title: "My Feed",
               link: "https://example.com",
               description: "A test feed",
               language: "en-us",
               ttl: 60,
               items: [
                 %Item{
                   title: "First Post",
                   link: "https://example.com/1",
                   description: "Hello world",
                   categories: [%Category{value: "tech"}]
                 }
               ]
             }
    end

    test "builds a full-featured feed with all sub-elements" do
      now = DateTime.utc_now()

      image = %Image{
        url: "https://blog.example.com/logo.png",
        title: "Tech Blog",
        link: "https://blog.example.com"
      }

      cloud = %Cloud{
        domain: "rpc.example.com",
        port: 80,
        path: "/RPC2",
        register_procedure: "notify",
        protocol: "xml-rpc"
      }

      text_input = %TextInput{
        title: "Search",
        description: "Search the feed",
        name: "q",
        link: "https://blog.example.com/search"
      }

      enclosure = %Enclosure{
        url: "https://blog.example.com/audio.mp3",
        length: 1_234_567,
        type: "audio/mpeg"
      }

      source = %Source{
        url: "https://upstream.example.com/rss",
        value: "Upstream Feed"
      }

      content_ns = "http://purl.org/rss/1.0/modules/content/"
      dc_ns = "http://purl.org/dc/elements/1.1/"
      content_ext = %{name: "encoded", attrs: %{}, value: "<p>Full article HTML</p>"}
      dc_ext = %{name: "rights", attrs: %{}, value: "CC BY 4.0"}

      first_item =
        Item.new()
        |> Item.put_title("Elixir OTP Tips")
        |> Item.put_link("https://blog.example.com/elixir-otp")
        |> Item.put_description("OTP patterns for production")
        |> Item.put_author("author@example.com")
        |> Item.put_comments("https://blog.example.com/elixir-otp#comments")
        |> Item.put_pub_date(now)
        |> Item.put_guid(%Guid{value: "https://blog.example.com/elixir-otp"})
        |> Item.put_enclosure(enclosure)
        |> Item.put_source(source)
        |> Item.add_category(%Category{value: "Elixir"})
        |> Item.add_category(%Category{value: "OTP"})
        |> Item.add_extension(content_ns, content_ext)

      second_item =
        Item.new()
        |> Item.put_title("RSS Feed Building")
        |> Item.put_link("https://blog.example.com/rss-building")
        |> Item.put_description("How to build RSS feeds")

      feed =
        Feed.new("Tech Blog", "https://blog.example.com", "Latest tech posts")
        |> Feed.put_language("en-us")
        |> Feed.put_copyright("2024 Example Inc.")
        |> Feed.put_managing_editor("editor@example.com")
        |> Feed.put_web_master("webmaster@example.com")
        |> Feed.put_pub_date(now)
        |> Feed.put_last_build_date(now)
        |> Feed.put_generator("Claptrap v0.1")
        |> Feed.put_docs("https://www.rssboard.org/rss-specification")
        |> Feed.put_ttl(30)
        |> Feed.put_image(image)
        |> Feed.put_cloud(cloud)
        |> Feed.put_text_input(text_input)
        |> Feed.put_namespace("content", content_ns)
        |> Feed.add_category(%Category{value: "Technology"})
        |> Feed.add_category(%Category{value: "Software", domain: "https://example.com/cats"})
        |> Feed.add_skip_hour(0)
        |> Feed.add_skip_hour(1)
        |> Feed.add_skip_day("Sunday")
        |> Feed.add_item(first_item)
        |> Feed.add_item(second_item)
        |> Feed.add_extension(dc_ns, dc_ext)

      assert feed == %Feed{
               title: "Tech Blog",
               link: "https://blog.example.com",
               description: "Latest tech posts",
               language: "en-us",
               copyright: "2024 Example Inc.",
               managing_editor: "editor@example.com",
               web_master: "webmaster@example.com",
               pub_date: now,
               last_build_date: now,
               generator: "Claptrap v0.1",
               docs: "https://www.rssboard.org/rss-specification",
               ttl: 30,
               rating: nil,
               image: image,
               cloud: cloud,
               text_input: text_input,
               namespaces: %{"content" => content_ns},
               categories: [
                 %Category{value: "Technology"},
                 %Category{value: "Software", domain: "https://example.com/cats"}
               ],
               skip_hours: [0, 1],
               skip_days: ["Sunday"],
               items: [first_item, second_item],
               extensions: %{dc_ns => [dc_ext]}
             }
    end

    property "pipeline-built feeds preserve all data through construction" do
      check all(
              title <- non_empty_string(),
              link <- url_string(),
              desc <- non_empty_string(),
              lang <- non_empty_string(),
              ttl <- StreamData.integer(0..1440),
              item_count <- StreamData.integer(0..5),
              item_titles <- StreamData.list_of(non_empty_string(), length: item_count)
            ) do
        items = Enum.map(item_titles, &Item.new(title: &1))

        feed =
          Enum.reduce(items, Feed.new(title, link, desc), fn item, acc ->
            Feed.add_item(acc, item)
          end)
          |> Feed.put_language(lang)
          |> Feed.put_ttl(ttl)

        assert feed == %Feed{
                 title: title,
                 link: link,
                 description: desc,
                 language: lang,
                 ttl: ttl,
                 items: items
               }
      end
    end
  end
end
