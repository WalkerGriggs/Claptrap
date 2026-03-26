defmodule Claptrap.RSS.ParserTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Claptrap.RSS.{Category, Cloud, Enclosure, Feed, Guid, Image, Item, ParseError, Parser, Source, TextInput}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp minimal_feed(overrides \\ "") do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>Test Feed</title>
        <link>https://example.com</link>
        <description>A test feed</description>
        #{overrides}
      </channel>
    </rss>
    """
  end

  defp enclosure_with_length(length) do
    ~s(<item><title>Has enclosure</title><enclosure url="https://example.com/audio.mp3" length="#{length}" type="audio/mpeg"/></item>)
  end

  defp mixed_enclosure_lengths(valid_length, invalid_length) do
    """
    <item>
      <title>Valid enclosure</title>
      <enclosure url="https://example.com/ok.mp3" length="#{valid_length}" type="audio/mpeg"/>
    </item>
    <item>
      <title>Invalid enclosure</title>
      <enclosure url="https://example.com/bad.mp3" length="#{invalid_length}" type="audio/mpeg"/>
    </item>
    """
  end

  # ---------------------------------------------------------------------------
  # Happy path
  # ---------------------------------------------------------------------------

  describe "minimal valid feed" do
    test "parses required channel elements" do
      assert {:ok, feed} = Parser.parse(minimal_feed())

      assert feed.title == "Test Feed"
      assert feed.link == "https://example.com"
      assert feed.description == "A test feed"
    end

    test "returns Feed struct" do
      assert {:ok, %Feed{}} = Parser.parse(minimal_feed())
    end

    test "optional fields default to nil/empty" do
      assert {:ok, feed} = Parser.parse(minimal_feed())

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
      assert feed.categories == []
      assert feed.skip_hours == []
      assert feed.skip_days == []
      assert feed.items == []
    end
  end

  describe "all optional channel elements" do
    test "parses all scalar optionals" do
      xml =
        minimal_feed("""
          <language>en-us</language>
          <copyright>Copyright 2024</copyright>
          <managingEditor>editor@example.com</managingEditor>
          <webMaster>webmaster@example.com</webMaster>
          <generator>MyGenerator 1.0</generator>
          <docs>https://www.rssboard.org/rss-specification</docs>
          <ttl>60</ttl>
          <rating>PG</rating>
        """)

      assert {:ok, feed} = Parser.parse(xml)

      assert feed.language == "en-us"
      assert feed.copyright == "Copyright 2024"
      assert feed.managing_editor == "editor@example.com"
      assert feed.web_master == "webmaster@example.com"
      assert feed.generator == "MyGenerator 1.0"
      assert feed.docs == "https://www.rssboard.org/rss-specification"
      assert feed.ttl == 60
      assert feed.rating == "PG"
    end

    test "parses pubDate" do
      xml = minimal_feed("<pubDate>Mon, 01 Jan 2024 00:00:00 GMT</pubDate>")
      assert {:ok, feed} = Parser.parse(xml)
      assert %DateTime{} = feed.pub_date
      assert feed.pub_date.year == 2024
    end

    test "parses lastBuildDate" do
      xml = minimal_feed("<lastBuildDate>Tue, 02 Jan 2024 12:30:00 +0000</lastBuildDate>")
      assert {:ok, feed} = Parser.parse(xml)
      assert %DateTime{} = feed.last_build_date
    end

    test "parses image element" do
      xml =
        minimal_feed("""
          <image>
            <url>https://example.com/logo.png</url>
            <title>Example Logo</title>
            <link>https://example.com</link>
            <width>100</width>
            <height>50</height>
            <description>Our logo</description>
          </image>
        """)

      assert {:ok, feed} = Parser.parse(xml)
      assert %Image{} = feed.image
      assert feed.image.url == "https://example.com/logo.png"
      assert feed.image.title == "Example Logo"
      assert feed.image.link == "https://example.com"
      assert feed.image.width == 100
      assert feed.image.height == 50
      assert feed.image.description == "Our logo"
    end

    test "parses textInput element" do
      xml =
        minimal_feed("""
          <textInput>
            <title>Search</title>
            <description>Search this feed</description>
            <name>q</name>
            <link>https://example.com/search</link>
          </textInput>
        """)

      assert {:ok, feed} = Parser.parse(xml)
      assert %TextInput{} = feed.text_input
      assert feed.text_input.title == "Search"
      assert feed.text_input.description == "Search this feed"
      assert feed.text_input.name == "q"
      assert feed.text_input.link == "https://example.com/search"
    end

    test "parses cloud element" do
      xml =
        minimal_feed("""
          <cloud domain="rpc.example.com" port="80" path="/RPC2"
                 registerProcedure="myCloud.rssPleaseNotify" protocol="xml-rpc"/>
        """)

      assert {:ok, feed} = Parser.parse(xml)
      assert %Cloud{} = feed.cloud
      assert feed.cloud.domain == "rpc.example.com"
      assert feed.cloud.port == 80
      assert feed.cloud.path == "/RPC2"
      assert feed.cloud.register_procedure == "myCloud.rssPleaseNotify"
      assert feed.cloud.protocol == "xml-rpc"
    end

    test "parses multiple categories" do
      xml =
        minimal_feed("""
          <category>Technology</category>
          <category domain="https://example.com/cats">Elixir</category>
        """)

      assert {:ok, feed} = Parser.parse(xml)
      assert length(feed.categories) == 2

      assert [
               %Category{value: "Technology", domain: nil},
               %Category{value: "Elixir", domain: "https://example.com/cats"}
             ] = feed.categories
    end

    test "parses skipHours" do
      xml = minimal_feed("<skipHours><hour>0</hour><hour>6</hour><hour>12</hour></skipHours>")
      assert {:ok, feed} = Parser.parse(xml)
      assert feed.skip_hours == [0, 6, 12]
    end

    test "parses skipDays" do
      xml = minimal_feed("<skipDays><day>Saturday</day><day>Sunday</day></skipDays>")
      assert {:ok, feed} = Parser.parse(xml)
      assert feed.skip_days == ["Saturday", "Sunday"]
    end
  end

  describe "items" do
    test "parses multiple items" do
      xml =
        minimal_feed("""
          <item>
            <title>Item One</title>
            <link>https://example.com/1</link>
          </item>
          <item>
            <title>Item Two</title>
            <link>https://example.com/2</link>
          </item>
        """)

      assert {:ok, feed} = Parser.parse(xml)
      assert length(feed.items) == 2
      assert [%Item{title: "Item One"}, %Item{title: "Item Two"}] = feed.items
    end

    test "parses item with all sub-elements" do
      xml =
        minimal_feed("""
          <item>
            <title>Full Item</title>
            <link>https://example.com/full</link>
            <description>Full description</description>
            <author>author@example.com</author>
            <comments>https://example.com/full#comments</comments>
            <pubDate>Wed, 03 Jan 2024 10:00:00 GMT</pubDate>
            <enclosure url="https://example.com/audio.mp3" length="12345" type="audio/mpeg"/>
            <guid isPermaLink="true">https://example.com/full</guid>
            <source url="https://other.com/feed">Other Feed</source>
            <category>Tech</category>
            <category domain="https://example.com/cats">Elixir</category>
          </item>
        """)

      assert {:ok, feed} = Parser.parse(xml)
      assert [item] = feed.items

      assert item.title == "Full Item"
      assert item.link == "https://example.com/full"
      assert item.description == "Full description"
      assert item.author == "author@example.com"
      assert item.comments == "https://example.com/full#comments"
      assert %DateTime{} = item.pub_date

      assert %Enclosure{url: "https://example.com/audio.mp3", length: 12_345, type: "audio/mpeg"} = item.enclosure

      assert %Guid{value: "https://example.com/full", is_perma_link: true} = item.guid

      assert %Source{value: "Other Feed", url: "https://other.com/feed"} = item.source

      assert length(item.categories) == 2
    end

    test "guid with isPermaLink=false" do
      xml = minimal_feed("<item><guid isPermaLink=\"false\">unique-id-123</guid></item>")
      assert {:ok, feed} = Parser.parse(xml)
      assert [item] = feed.items
      assert %Guid{value: "unique-id-123", is_perma_link: false} = item.guid
    end

    test "item with no title or link still parses" do
      xml = minimal_feed("<item><description>Just a description</description></item>")
      assert {:ok, feed} = Parser.parse(xml)
      assert [item] = feed.items
      assert item.title == nil
      assert item.link == nil
      assert item.description == "Just a description"
    end
  end

  describe "namespace declarations" do
    test "namespace prefixes preserved in feed.namespaces" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:content="http://purl.org/rss/1.0/modules/content/">
        <channel>
          <title>Test</title>
          <link>https://example.com</link>
          <description>Test</description>
        </channel>
      </rss>
      """

      assert {:ok, feed} = Parser.parse(xml)
      assert feed.namespaces["dc"] == "http://purl.org/dc/elements/1.1/"
      assert feed.namespaces["content"] == "http://purl.org/rss/1.0/modules/content/"
    end

    test "extension elements collected into feed.extensions" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/">
        <channel>
          <title>Test</title>
          <link>https://example.com</link>
          <description>Test</description>
          <dc:creator>John Doe</dc:creator>
        </channel>
      </rss>
      """

      assert {:ok, feed} = Parser.parse(xml)
      dc_uri = "http://purl.org/dc/elements/1.1/"
      assert Map.has_key?(feed.extensions, dc_uri)
      assert [%{name: "creator", value: "John Doe"}] = feed.extensions[dc_uri]
    end

    test "item extension elements collected into item.extensions" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/">
        <channel>
          <title>Test</title>
          <link>https://example.com</link>
          <description>Test</description>
          <item>
            <title>Item</title>
            <dc:creator>Jane Smith</dc:creator>
          </item>
        </channel>
      </rss>
      """

      assert {:ok, feed} = Parser.parse(xml)
      assert [item] = feed.items
      dc_uri = "http://purl.org/dc/elements/1.1/"
      assert Map.has_key?(item.extensions, dc_uri)
      assert [%{name: "creator", value: "Jane Smith"}] = item.extensions[dc_uri]
    end

    test "nested extension elements preserved" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/">
        <channel>
          <title>Test</title>
          <link>https://example.com</link>
          <description>Test</description>
          <item>
            <title>Item</title>
            <media:group>
              <media:content url="https://example.com/video.mp4" type="video/mp4"/>
            </media:group>
          </item>
        </channel>
      </rss>
      """

      assert {:ok, feed} = Parser.parse(xml)
      assert [item] = feed.items
      media_uri = "http://search.yahoo.com/mrss/"
      assert Map.has_key?(item.extensions, media_uri)
      [group_ext] = item.extensions[media_uri]
      assert group_ext.name == "group"
      assert is_list(group_ext.value)
    end
  end

  # ---------------------------------------------------------------------------
  # Lenient mode (default)
  # ---------------------------------------------------------------------------

  describe "lenient mode" do
    test "missing link fills with empty string" do
      xml = """
      <?xml version="1.0"?>
      <rss version="2.0">
        <channel>
          <title>No Link Feed</title>
          <description>A feed without a link</description>
        </channel>
      </rss>
      """

      assert {:ok, feed} = Parser.parse(xml)
      assert feed.link == ""
    end

    test "missing description fills with empty string" do
      xml = """
      <?xml version="1.0"?>
      <rss version="2.0">
        <channel>
          <title>No Desc Feed</title>
          <link>https://example.com</link>
        </channel>
      </rss>
      """

      assert {:ok, feed} = Parser.parse(xml)
      assert feed.description == ""
    end

    test "malformed date becomes nil" do
      xml = minimal_feed("<pubDate>not-a-date</pubDate>")
      assert {:ok, feed} = Parser.parse(xml)
      assert feed.pub_date == nil
    end

    test "malformed item pubDate becomes nil" do
      xml =
        minimal_feed("""
          <item>
            <title>Bad Date Item</title>
            <pubDate>not-a-date</pubDate>
          </item>
        """)

      assert {:ok, feed} = Parser.parse(xml)
      assert [item] = feed.items
      assert item.pub_date == nil
    end

    test "ttl with trailing garbage is dropped" do
      xml = minimal_feed("<ttl>60abc</ttl>")
      assert {:ok, feed} = Parser.parse(xml)
      assert feed.ttl == nil
    end

    test "skipHours hour with trailing garbage is dropped" do
      xml = minimal_feed("<skipHours><hour>12x</hour><hour>8</hour></skipHours>")
      assert {:ok, feed} = Parser.parse(xml)
      assert feed.skip_hours == [8]
    end

    test "enclosure length with trailing garbage falls back to 0" do
      xml =
        minimal_feed(enclosure_with_length("1000bytes"))

      assert {:ok, feed} = Parser.parse(xml)
      assert [%Item{enclosure: %Enclosure{length: 0}}] = feed.items
    end

    test "cloud port with trailing garbage falls back to 0" do
      xml =
        minimal_feed("""
          <cloud domain="rpc.example.com" port="80abc" path="/RPC2"
                 registerProcedure="myCloud.rssPleaseNotify" protocol="xml-rpc"/>
        """)

      assert {:ok, feed} = Parser.parse(xml)
      assert %Cloud{port: 0} = feed.cloud
    end

    test "duplicate title takes first occurrence" do
      xml =
        minimal_feed("""
          <title>First Title</title>
          <title>Second Title</title>
        """)

      assert {:ok, feed} = Parser.parse(xml)
      assert feed.title == "Test Feed"
    end

    test "CDATA description extracted correctly" do
      xml =
        minimal_feed(
          "<item><title>CDATA Item</title><description><![CDATA[<p>HTML content here</p>]]></description></item>"
        )

      assert {:ok, feed} = Parser.parse(xml)
      assert [item] = feed.items
      assert item.description == "<p>HTML content here</p>"
    end

    test "self-closing empty element resolves to nil" do
      xml = minimal_feed("<item><title>Item</title><description/></item>")
      assert {:ok, feed} = Parser.parse(xml)
      assert [item] = feed.items
      assert item.description == nil
    end

    test "empty tag element resolves to nil" do
      xml = minimal_feed("<item><title>Item</title><description></description></item>")
      assert {:ok, feed} = Parser.parse(xml)
      assert [item] = feed.items
      assert item.description == nil
    end

    test "items before channel metadata still parse" do
      xml = """
      <?xml version="1.0"?>
      <rss version="2.0">
        <channel>
          <item>
            <title>Early Item</title>
          </item>
          <title>Late Title</title>
          <link>https://example.com</link>
          <description>Late Description</description>
        </channel>
      </rss>
      """

      assert {:ok, feed} = Parser.parse(xml)
      assert feed.title == "Late Title"
      assert length(feed.items) == 1
      assert hd(feed.items).title == "Early Item"
    end
  end

  # ---------------------------------------------------------------------------
  # Strict mode
  # ---------------------------------------------------------------------------

  describe "strict mode" do
    test "missing title returns ParseError" do
      xml = """
      <?xml version="1.0"?>
      <rss version="2.0">
        <channel>
          <link>https://example.com</link>
          <description>No title here</description>
        </channel>
      </rss>
      """

      assert {:error, %ParseError{reason: :missing_required_field}} = Parser.parse(xml, strict: true)
    end

    test "missing link returns ParseError" do
      xml = """
      <?xml version="1.0"?>
      <rss version="2.0">
        <channel>
          <title>Test</title>
          <description>No link here</description>
        </channel>
      </rss>
      """

      assert {:error, %ParseError{reason: :missing_required_field}} = Parser.parse(xml, strict: true)
    end

    test "missing description returns ParseError" do
      xml = """
      <?xml version="1.0"?>
      <rss version="2.0">
        <channel>
          <title>Test</title>
          <link>https://example.com</link>
        </channel>
      </rss>
      """

      assert {:error, %ParseError{reason: :missing_required_field}} = Parser.parse(xml, strict: true)
    end

    test "malformed date returns ParseError" do
      xml = minimal_feed("<pubDate>not-a-date</pubDate>")
      assert {:error, %ParseError{reason: :malformed_date}} = Parser.parse(xml, strict: true)
    end

    test "malformed item pubDate returns ParseError" do
      xml =
        minimal_feed("""
          <item>
            <title>Bad Date Item</title>
            <pubDate>not-a-date</pubDate>
          </item>
        """)

      assert {:error, %ParseError{reason: :malformed_date, message: "malformed date: not-a-date"}} =
               Parser.parse(xml, strict: true)
    end

    test "short-circuits on first malformed item pubDate" do
      xml =
        minimal_feed("""
          <item>
            <title>Valid Item</title>
            <pubDate>Mon, 01 Jan 2024 00:00:00 GMT</pubDate>
          </item>
          <item>
            <title>First Malformed</title>
            <pubDate>not-a-date-first</pubDate>
          </item>
          <item>
            <title>Second Malformed</title>
            <pubDate>not-a-date-second</pubDate>
          </item>
        """)

      assert {:error,
              %ParseError{
                reason: :malformed_date,
                message: "malformed date: not-a-date-first"
              }} = Parser.parse(xml, strict: true)
    end

    test "ttl with trailing garbage returns ParseError" do
      xml = minimal_feed("<ttl>60abc</ttl>")
      assert {:error, %ParseError{reason: :malformed_integer}} = Parser.parse(xml, strict: true)
    end

    test "skipHours hour with trailing garbage returns ParseError" do
      xml = minimal_feed("<skipHours><hour>12x</hour></skipHours>")
      assert {:error, %ParseError{reason: :malformed_integer}} = Parser.parse(xml, strict: true)
    end

    test "enclosure length with trailing garbage returns ParseError" do
      xml =
        minimal_feed(enclosure_with_length("1000bytes"))

      assert {:error, %ParseError{reason: :malformed_integer}} = Parser.parse(xml, strict: true)
    end

    test "cloud port with trailing garbage returns ParseError" do
      xml =
        minimal_feed("""
          <cloud domain="rpc.example.com" port="80abc" path="/RPC2"
                 registerProcedure="myCloud.rssPleaseNotify" protocol="xml-rpc"/>
        """)

      assert {:error, %ParseError{reason: :malformed_integer}} = Parser.parse(xml, strict: true)
    end

    test "empty ttl returns ParseError" do
      xml = minimal_feed("<ttl>   </ttl>")
      assert {:error, %ParseError{reason: :malformed_integer}} = Parser.parse(xml, strict: true)
    end

    test "empty skipHours hour returns ParseError" do
      xml = minimal_feed("<skipHours><hour/></skipHours>")
      assert {:error, %ParseError{reason: :malformed_integer}} = Parser.parse(xml, strict: true)
    end

    test "empty cloud port returns ParseError" do
      xml =
        minimal_feed("""
          <cloud domain="rpc.example.com" port="" path="/RPC2"
                 registerProcedure="myCloud.rssPleaseNotify" protocol="xml-rpc"/>
        """)

      assert {:error, %ParseError{reason: :malformed_integer}} = Parser.parse(xml, strict: true)
    end

    test "empty enclosure length returns ParseError" do
      xml =
        minimal_feed(enclosure_with_length(""))

      assert {:error, %ParseError{reason: :malformed_integer}} = Parser.parse(xml, strict: true)
    end

    test "malformed enclosure length in later item still fails strict parse" do
      xml = minimal_feed(mixed_enclosure_lengths("1000", "1000bytes"))

      assert {:error, %ParseError{reason: :malformed_integer, message: message}} =
               Parser.parse(xml, strict: true)

      assert message =~ "item.enclosure.length"
    end

    test "valid integer fields parse in strict mode" do
      xml =
        minimal_feed("""
          <ttl>60</ttl>
          <cloud domain="rpc.example.com" port="80" path="/RPC2"
                 registerProcedure="myCloud.rssPleaseNotify" protocol="xml-rpc"/>
          <skipHours><hour>0</hour><hour>12</hour></skipHours>
          <item>
            <title>Item One</title>
            <enclosure url="https://example.com/audio.mp3" length="1000" type="audio/mpeg"/>
          </item>
        """)

      assert {:ok, feed} = Parser.parse(xml, strict: true)
      assert feed.ttl == 60
      assert feed.cloud.port == 80
      assert feed.skip_hours == [0, 12]
      assert [%Item{enclosure: %Enclosure{length: 1000}}] = feed.items
    end

    test "valid feed parses successfully in strict mode" do
      assert {:ok, %Feed{}} = Parser.parse(minimal_feed(), strict: true)
    end
  end

  # ---------------------------------------------------------------------------
  # Error cases
  # ---------------------------------------------------------------------------

  describe "error cases" do
    @describetag capture_log: true
    test "binary garbage returns ParseError with :invalid_xml" do
      assert {:error, %ParseError{reason: :invalid_xml}} = Parser.parse("<<< not xml >>>")
    end

    test "empty string returns ParseError with :invalid_xml" do
      assert {:error, %ParseError{reason: :invalid_xml}} = Parser.parse("")
    end

    test "truncated XML returns ParseError with :invalid_xml" do
      assert {:error, %ParseError{reason: :invalid_xml}} = Parser.parse("<rss><channel><title>Trun")
    end

    test "valid XML but not RSS returns ParseError with :missing_channel" do
      html = """
      <?xml version="1.0"?>
      <html>
        <body>Not RSS</body>
      </html>
      """

      assert {:error, %ParseError{reason: :missing_channel}} = Parser.parse(html)
    end

    test "RSS without channel returns ParseError with :missing_channel" do
      xml = """
      <?xml version="1.0"?>
      <rss version="2.0">
      </rss>
      """

      assert {:error, %ParseError{reason: :missing_channel}} = Parser.parse(xml)
    end

    test "non-binary input returns ParseError" do
      assert {:error, %ParseError{reason: :invalid_xml}} = Parser.parse(42)
      assert {:error, %ParseError{reason: :invalid_xml}} = Parser.parse(nil)
      assert {:error, %ParseError{reason: :invalid_xml}} = Parser.parse([:not, :xml])
    end
  end

  # ---------------------------------------------------------------------------
  # Dependency injection
  # ---------------------------------------------------------------------------

  describe "custom xml_backend" do
    defmodule FakeXmlBackend do
      @behaviour Claptrap.RSS.XmlBackend

      @impl true
      def scan(_xml) do
        {:error, :custom_backend_called}
      end
    end

    test "custom xml_backend is called instead of default" do
      result = Parser.parse(minimal_feed(), xml_backend: FakeXmlBackend)
      assert {:error, _} = result
    end
  end

  describe "custom date_module" do
    defmodule FixedDateModule do
      @behaviour Claptrap.RSS.DateBehaviour

      @fixed_dt ~U[2024-01-01 00:00:00Z]

      @impl true
      def parse(_binary), do: {:ok, @fixed_dt}

      @impl true
      def format(_dt), do: "Mon, 01 Jan 2024 00:00:00 +0000"
    end

    test "custom date_module is used for date parsing" do
      xml = minimal_feed("<pubDate>anything</pubDate>")
      assert {:ok, feed} = Parser.parse(xml, date_module: FixedDateModule)
      assert feed.pub_date == ~U[2024-01-01 00:00:00Z]
    end
  end

  # ---------------------------------------------------------------------------
  # Property-based tests
  # ---------------------------------------------------------------------------

  describe "property: never raises" do
    property "parsing any binary never raises" do
      check all(bin <- binary()) do
        result = Parser.parse(bin)
        assert match?({:ok, _}, result) or match?({:error, %ParseError{}}, result)
      end
    end

    property "parsing any string never raises" do
      check all(str <- string(:printable)) do
        result = Parser.parse(str)
        assert match?({:ok, _}, result) or match?({:error, %ParseError{}}, result)
      end
    end
  end

  describe "property: valid feeds parse successfully" do
    property "feed with various titles and descriptions parses" do
      # Restrict to ASCII to avoid supplementary-plane codepoints that xmerl rejects
      ascii_printable = string(:ascii, min_length: 1)

      check all(
              title <- ascii_printable,
              link <- ascii_printable,
              description <- ascii_printable
            ) do
        safe_title = String.replace(title, ~r/[<>&"'\x00-\x1F]/, "")
        safe_link = String.replace(link, ~r/[<>&"'\x00-\x1F]/, "")
        safe_desc = String.replace(description, ~r/[<>&"'\x00-\x1F]/, "")

        if safe_title != "" and safe_link != "" and safe_desc != "" do
          xml = """
          <?xml version="1.0"?>
          <rss version="2.0">
            <channel>
              <title>#{safe_title}</title>
              <link>#{safe_link}</link>
              <description>#{safe_desc}</description>
            </channel>
          </rss>
          """

          assert {:ok, feed} = Parser.parse(xml)

          expected_title =
            safe_title
            |> String.replace(~r/\s+/, " ")
            |> String.trim()

          assert feed.title == expected_title
        end
      end
    end

    property "ttl parses as integer when valid" do
      check all(n <- integer(0..65_535)) do
        xml = minimal_feed("<ttl>#{n}</ttl>")
        assert {:ok, feed} = Parser.parse(xml)
        assert feed.ttl == n
      end
    end

    property "skip_hours integers are preserved" do
      check all(hours <- list_of(integer(0..23), max_length: 24)) do
        hour_xml = Enum.map_join(hours, "\n", fn h -> "<hour>#{h}</hour>" end)
        xml = minimal_feed("<skipHours>#{hour_xml}</skipHours>")
        assert {:ok, feed} = Parser.parse(xml)
        assert feed.skip_hours == hours
      end
    end

    property "ttl rejects any non-empty suffix after integer" do
      safe_suffix =
        StreamData.string(:ascii, min_length: 1, max_length: 8)
        |> StreamData.map(&String.replace(&1, ~r/[<>&"']/, ""))
        |> StreamData.filter(&(String.trim(&1) != ""))

      check all(
              n <- integer(0..65_535),
              suffix <- safe_suffix
            ) do
        xml = minimal_feed("<ttl>#{n}#{suffix}</ttl>")

        assert {:ok, feed} = Parser.parse(xml)
        assert feed.ttl == nil

        assert {:error, %ParseError{reason: :malformed_integer}} = Parser.parse(xml, strict: true)
      end
    end

    property "ttl accepts pure integer surrounded by whitespace" do
      whitespace =
        StreamData.member_of([" ", "\t", "\n", "\r"])
        |> StreamData.list_of(max_length: 3)
        |> StreamData.map(&Enum.join/1)

      check all(
              n <- integer(0..65_535),
              left <- whitespace,
              right <- whitespace
            ) do
        xml = minimal_feed("<ttl>#{left}#{n}#{right}</ttl>")

        assert {:ok, feed} = Parser.parse(xml)
        assert feed.ttl == n

        assert {:ok, strict_feed} = Parser.parse(xml, strict: true)
        assert strict_feed.ttl == n
      end
    end
  end

  describe "property: malformed item pubDate mode behavior" do
    property "strict rejects malformed item pubDate while lenient coerces to nil" do
      check all(suffix <- string(:alphanumeric, min_length: 1)) do
        raw = "INVALID-#{suffix}"

        xml =
          minimal_feed("""
            <item>
              <title>Bad Date Item</title>
              <pubDate>#{raw}</pubDate>
            </item>
          """)

        assert {:ok, lenient_feed} = Parser.parse(xml)
        assert [lenient_item] = lenient_feed.items
        assert lenient_item.pub_date == nil

        assert {:error, %ParseError{reason: :malformed_date, message: message}} =
                 Parser.parse(xml, strict: true)

        assert message == "malformed date: #{raw}"
      end
    end
  end
end
