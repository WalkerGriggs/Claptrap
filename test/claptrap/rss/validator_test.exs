defmodule Claptrap.RSS.ValidatorTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Claptrap.RSS.{
    Category,
    Cloud,
    Enclosure,
    Feed,
    Guid,
    Image,
    Item,
    ValidationError,
    Validator
  }

  # -- Helpers -----------------------------------------------------------

  defp valid_feed do
    %Feed{title: "Test Channel", link: "https://example.com", description: "A test feed"}
  end

  defp valid_item do
    %Item{title: "Test Item"}
  end

  defp valid_image do
    %Image{url: "https://example.com/img.png", title: "Logo", link: "https://example.com"}
  end

  defp valid_cloud do
    %Cloud{
      domain: "rpc.example.com",
      port: 80,
      path: "/RPC2",
      register_procedure: "notify",
      protocol: "xml-rpc"
    }
  end

  defp valid_enclosure do
    %Enclosure{url: "https://example.com/ep.mp3", length: 12_216_320, type: "audio/mpeg"}
  end

  defp errors_for(feed) do
    {:error, errors} = Validator.validate(feed)
    errors
  end

  defp has_error?(errors, opts) do
    Enum.any?(errors, fn %ValidationError{} = e ->
      Enum.all?(opts, fn
        {:rule, rule} -> e.rule == rule
        {:path, path} -> e.path == path
        {:message, msg} -> String.contains?(e.message, msg)
      end)
    end)
  end

  defp add_item(feed, item), do: %{feed | items: feed.items ++ [item]}
  defp put_image(feed, image), do: %{feed | image: image}
  defp put_cloud(feed, cloud), do: %{feed | cloud: cloud}

  # -- Valid feed ---------------------------------------------------------

  describe "valid feed" do
    test "minimal valid feed returns :ok" do
      assert :ok = Validator.validate(valid_feed())
    end

    test "feed with valid items returns :ok" do
      feed = add_item(valid_feed(), valid_item())
      assert :ok = Validator.validate(feed)
    end

    test "feed with all optional elements returns :ok" do
      item = %Item{
        title: "Item 1",
        link: "https://example.com/1",
        enclosure: valid_enclosure(),
        guid: %Guid{value: "https://example.com/1", is_perma_link: true},
        categories: [%Category{value: "News"}]
      }

      feed = %{
        valid_feed()
        | ttl: 60,
          image: valid_image(),
          cloud: valid_cloud(),
          skip_hours: [0, 12],
          skip_days: ["Saturday", "Sunday"],
          categories: [%Category{value: "Tech"}],
          items: [item]
      }

      assert :ok = Validator.validate(feed)
    end
  end

  # -- Channel-level validation ------------------------------------------

  describe "channel required fields" do
    test "empty title returns :required error" do
      feed = %{valid_feed() | title: ""}
      errors = errors_for(feed)

      assert has_error?(errors, rule: :required, path: [:title])
    end

    test "nil title returns :required error" do
      feed = struct(Feed, %{title: nil, link: "https://example.com", description: "desc"})
      errors = errors_for(feed)

      assert has_error?(errors, rule: :required, path: [:title])
    end

    test "empty link returns :required error" do
      feed = %{valid_feed() | link: ""}
      errors = errors_for(feed)

      assert has_error?(errors, rule: :required, path: [:link])
    end

    test "empty description returns :required error" do
      feed = %{valid_feed() | description: ""}
      errors = errors_for(feed)

      assert has_error?(errors, rule: :required, path: [:description])
    end

    test "all three empty returns three :required errors" do
      feed = struct(Feed, %{title: "", link: "", description: ""})
      errors = errors_for(feed)

      assert has_error?(errors, rule: :required, path: [:title])
      assert has_error?(errors, rule: :required, path: [:link])
      assert has_error?(errors, rule: :required, path: [:description])
    end
  end

  describe "channel link format" do
    test "link without scheme returns :format error" do
      feed = %{valid_feed() | link: "example.com"}
      errors = errors_for(feed)

      assert has_error?(errors, rule: :format, path: [:link])
    end

    test "link with scheme but empty opaque part returns :format error" do
      feed = %{valid_feed() | link: "mailto:"}
      errors = errors_for(feed)

      assert has_error?(errors, rule: :format, path: [:link])
    end

    test "link starting with colon returns :format error" do
      feed = %{valid_feed() | link: ":not-a-scheme"}
      errors = errors_for(feed)

      assert has_error?(errors, rule: :format, path: [:link])
    end

    test "link with valid http scheme passes" do
      assert :ok = Validator.validate(%{valid_feed() | link: "http://example.com"})
    end

    test "link with valid https scheme passes" do
      assert :ok = Validator.validate(valid_feed())
    end

    test "link with ftp scheme passes" do
      assert :ok = Validator.validate(%{valid_feed() | link: "ftp://files.example.com"})
    end

    test "link with mailto scheme passes" do
      assert :ok =
               Validator.validate(%{
                 valid_feed()
                 | link: "mailto:foo@example.com"
               })
    end

    test "link with opaque news scheme passes" do
      assert :ok =
               Validator.validate(%{
                 valid_feed()
                 | link: "news:comp.lang.elixir"
               })
    end

    test "link with news hierarchical form passes" do
      assert :ok =
               Validator.validate(%{
                 valid_feed()
                 | link: "news://news.example.com/group"
               })
    end
  end

  describe "channel ttl" do
    test "ttl of 0 is valid" do
      feed = %{valid_feed() | ttl: 0}
      assert :ok = Validator.validate(feed)
    end

    test "positive ttl is valid" do
      feed = %{valid_feed() | ttl: 60}
      assert :ok = Validator.validate(feed)
    end

    test "negative ttl returns :type error" do
      feed = %{valid_feed() | ttl: -1}
      errors = errors_for(feed)

      assert has_error?(errors, rule: :type, path: [:ttl])
    end

    test "non-integer ttl returns :type error" do
      feed = %{valid_feed() | ttl: "sixty"}
      errors = errors_for(feed)

      assert has_error?(errors, rule: :type, path: [:ttl])
    end

    test "float ttl returns :type error" do
      feed = %{valid_feed() | ttl: 60.5}
      errors = errors_for(feed)

      assert has_error?(errors, rule: :type, path: [:ttl])
    end
  end

  # -- Item-level validation ---------------------------------------------

  describe "item title/description requirement" do
    test "item with only title is valid" do
      feed = add_item(valid_feed(), %Item{title: "Title"})
      assert :ok = Validator.validate(feed)
    end

    test "item with only description is valid" do
      feed = add_item(valid_feed(), %Item{description: "Desc"})
      assert :ok = Validator.validate(feed)
    end

    test "item with both title and description is valid" do
      feed = add_item(valid_feed(), %Item{title: "T", description: "D"})
      assert :ok = Validator.validate(feed)
    end

    test "item with neither title nor description returns :required error" do
      feed = add_item(valid_feed(), %Item{})
      errors = errors_for(feed)

      assert has_error?(errors, rule: :required, path: [:items, 0])
    end

    test "item with empty string title and nil description returns :required error" do
      feed = add_item(valid_feed(), %Item{title: "", description: nil})
      errors = errors_for(feed)

      assert has_error?(errors, rule: :required, path: [:items, 0])
    end
  end

  describe "item link format" do
    test "item with valid link passes" do
      feed = add_item(valid_feed(), %Item{title: "T", link: "https://example.com/1"})
      assert :ok = Validator.validate(feed)
    end

    test "item with invalid link returns :format error" do
      feed = add_item(valid_feed(), %Item{title: "T", link: "not-a-url"})
      errors = errors_for(feed)

      assert has_error?(errors, rule: :format, path: [:items, 0, :link])
    end

    test "item with mailto link passes" do
      feed =
        add_item(valid_feed(), %Item{
          title: "T",
          link: "mailto:author@example.com"
        })

      assert :ok = Validator.validate(feed)
    end

    test "item with news link passes" do
      feed =
        add_item(valid_feed(), %Item{
          title: "T",
          link: "news:comp.example"
        })

      assert :ok = Validator.validate(feed)
    end

    test "item without link passes" do
      feed = add_item(valid_feed(), %Item{title: "T"})
      assert :ok = Validator.validate(feed)
    end
  end

  describe "enclosure validation" do
    test "valid enclosure passes" do
      item = %Item{title: "T", enclosure: valid_enclosure()}
      feed = add_item(valid_feed(), item)
      assert :ok = Validator.validate(feed)
    end

    test "enclosure with negative length returns :type error" do
      enc = %Enclosure{url: "https://example.com/f.mp3", length: -1, type: "audio/mpeg"}
      feed = add_item(valid_feed(), %Item{title: "T", enclosure: enc})
      errors = errors_for(feed)

      assert has_error?(errors, rule: :type, path: [:items, 0, :enclosure, :length])
    end

    test "enclosure with empty url returns :required error" do
      enc = %Enclosure{url: "", length: 100, type: "audio/mpeg"}
      feed = add_item(valid_feed(), %Item{title: "T", enclosure: enc})
      errors = errors_for(feed)

      assert has_error?(errors, rule: :required, path: [:items, 0, :enclosure, :url])
    end

    test "enclosure with empty type returns :required error" do
      enc = %Enclosure{url: "https://example.com/f.mp3", length: 100, type: ""}
      feed = add_item(valid_feed(), %Item{title: "T", enclosure: enc})
      errors = errors_for(feed)

      assert has_error?(errors, rule: :required, path: [:items, 0, :enclosure, :type])
    end

    test "enclosure url without scheme returns :format error" do
      enc = %Enclosure{url: "example.com/f.mp3", length: 100, type: "audio/mpeg"}
      feed = add_item(valid_feed(), %Item{title: "T", enclosure: enc})
      errors = errors_for(feed)

      assert has_error?(errors, rule: :format, path: [:items, 0, :enclosure, :url])
    end

    test "enclosure with mailto url passes" do
      enc = %Enclosure{
        url: "mailto:podcast@example.com",
        length: 0,
        type: "text/html"
      }

      feed = add_item(valid_feed(), %Item{title: "T", enclosure: enc})
      assert :ok = Validator.validate(feed)
    end

    test "enclosure with news url passes" do
      enc = %Enclosure{url: "news:announce.example", length: 0, type: "message/rfc822"}
      feed = add_item(valid_feed(), %Item{title: "T", enclosure: enc})
      assert :ok = Validator.validate(feed)
    end
  end

  describe "guid validation" do
    test "guid with is_perma_link=true and valid URL passes" do
      item = %Item{
        title: "T",
        guid: %Guid{value: "https://example.com/1", is_perma_link: true}
      }

      feed = add_item(valid_feed(), item)
      assert :ok = Validator.validate(feed)
    end

    test "guid with is_perma_link=true and non-URL returns :format error" do
      item = %Item{
        title: "T",
        guid: %Guid{value: "not-a-url-123", is_perma_link: true}
      }

      feed = add_item(valid_feed(), item)
      errors = errors_for(feed)

      assert has_error?(errors, rule: :format, path: [:items, 0, :guid, :value])
    end

    test "guid with is_perma_link=true and mailto URI passes" do
      item = %Item{
        title: "T",
        guid: %Guid{value: "mailto:item@example.com", is_perma_link: true}
      }

      feed = add_item(valid_feed(), item)
      assert :ok = Validator.validate(feed)
    end

    test "guid with is_perma_link=true and news URI passes" do
      item = %Item{
        title: "T",
        guid: %Guid{value: "news:guid.example", is_perma_link: true}
      }

      feed = add_item(valid_feed(), item)
      assert :ok = Validator.validate(feed)
    end

    test "guid with is_perma_link=false and non-URL passes" do
      item = %Item{
        title: "T",
        guid: %Guid{value: "arbitrary-id-123", is_perma_link: false}
      }

      feed = add_item(valid_feed(), item)
      assert :ok = Validator.validate(feed)
    end

    test "no guid passes" do
      feed = add_item(valid_feed(), %Item{title: "T"})
      assert :ok = Validator.validate(feed)
    end
  end

  # -- Image validation --------------------------------------------------

  describe "image validation" do
    test "valid image passes" do
      feed = put_image(valid_feed(), valid_image())
      assert :ok = Validator.validate(feed)
    end

    test "image with width > 144 returns :range error" do
      feed = put_image(valid_feed(), %{valid_image() | width: 145})
      errors = errors_for(feed)

      assert has_error?(errors, rule: :range, path: [:image, :width])
    end

    test "image with width = 144 passes" do
      feed = put_image(valid_feed(), %{valid_image() | width: 144})
      assert :ok = Validator.validate(feed)
    end

    test "image with height > 400 returns :range error" do
      feed = put_image(valid_feed(), %{valid_image() | height: 401})
      errors = errors_for(feed)

      assert has_error?(errors, rule: :range, path: [:image, :height])
    end

    test "image with height = 400 passes" do
      feed = put_image(valid_feed(), %{valid_image() | height: 400})
      assert :ok = Validator.validate(feed)
    end

    test "image with nil width and height passes" do
      feed = put_image(valid_feed(), valid_image())
      assert :ok = Validator.validate(feed)
    end

    test "image with empty url returns :required error" do
      feed = put_image(valid_feed(), %{valid_image() | url: ""})
      errors = errors_for(feed)

      assert has_error?(errors, rule: :required, path: [:image, :url])
    end

    test "image with empty title returns :required error" do
      feed = put_image(valid_feed(), %{valid_image() | title: ""})
      errors = errors_for(feed)

      assert has_error?(errors, rule: :required, path: [:image, :title])
    end

    test "image with empty link returns :required error" do
      feed = put_image(valid_feed(), %{valid_image() | link: ""})
      errors = errors_for(feed)

      assert has_error?(errors, rule: :required, path: [:image, :link])
    end

    test "image url without scheme returns :format error" do
      feed = put_image(valid_feed(), %{valid_image() | url: "example.com/img.png"})
      errors = errors_for(feed)

      assert has_error?(errors, rule: :format, path: [:image, :url])
    end
  end

  # -- Cloud validation --------------------------------------------------

  describe "cloud validation" do
    test "valid cloud passes" do
      feed = put_cloud(valid_feed(), valid_cloud())
      assert :ok = Validator.validate(feed)
    end

    test "cloud with empty domain returns :required error" do
      feed = put_cloud(valid_feed(), %{valid_cloud() | domain: ""})
      errors = errors_for(feed)

      assert has_error?(errors, rule: :required, path: [:cloud, :domain])
    end

    test "cloud with empty path returns :required error" do
      feed = put_cloud(valid_feed(), %{valid_cloud() | path: ""})
      errors = errors_for(feed)

      assert has_error?(errors, rule: :required, path: [:cloud, :path])
    end

    test "cloud with empty register_procedure returns :required error" do
      feed = put_cloud(valid_feed(), %{valid_cloud() | register_procedure: ""})
      errors = errors_for(feed)

      assert has_error?(errors, rule: :required, path: [:cloud, :register_procedure])
    end

    test "cloud with invalid protocol returns :format error" do
      feed = put_cloud(valid_feed(), %{valid_cloud() | protocol: "grpc"})
      errors = errors_for(feed)

      assert has_error?(errors, rule: :format, path: [:cloud, :protocol])
    end

    test "cloud with soap protocol passes" do
      feed = put_cloud(valid_feed(), %{valid_cloud() | protocol: "soap"})
      assert :ok = Validator.validate(feed)
    end

    test "cloud with http-post protocol passes" do
      feed = put_cloud(valid_feed(), %{valid_cloud() | protocol: "http-post"})
      assert :ok = Validator.validate(feed)
    end

    test "cloud with negative port returns :type error" do
      feed = put_cloud(valid_feed(), %{valid_cloud() | port: -1})
      errors = errors_for(feed)

      assert has_error?(errors, rule: :type, path: [:cloud, :port])
    end
  end

  # -- Skip hours --------------------------------------------------------

  describe "skip_hours validation" do
    test "valid skip_hours passes" do
      feed = %{valid_feed() | skip_hours: [0, 12, 23]}
      assert :ok = Validator.validate(feed)
    end

    test "skip_hours value of 25 returns :range error" do
      feed = %{valid_feed() | skip_hours: [25]}
      errors = errors_for(feed)

      assert has_error?(errors, rule: :range, path: [:skip_hours])
    end

    test "skip_hours value of -1 returns :range error" do
      feed = %{valid_feed() | skip_hours: [-1]}
      errors = errors_for(feed)

      assert has_error?(errors, rule: :range, path: [:skip_hours])
    end

    test "non-integer skip_hours returns :range error" do
      feed = %{valid_feed() | skip_hours: ["noon"]}
      errors = errors_for(feed)

      assert has_error?(errors, rule: :range, path: [:skip_hours])
    end

    test "duplicate skip_hours returns :format error" do
      feed = %{valid_feed() | skip_hours: [0, 12, 12]}
      errors = errors_for(feed)

      assert has_error?(errors, rule: :format, path: [:skip_hours])
    end

    test "empty skip_hours passes" do
      assert :ok = Validator.validate(valid_feed())
    end
  end

  # -- Skip days ---------------------------------------------------------

  describe "skip_days validation" do
    test "valid skip_days passes" do
      feed = %{valid_feed() | skip_days: ["Saturday", "Sunday"]}
      assert :ok = Validator.validate(feed)
    end

    test "invalid day name returns :format error" do
      feed = %{valid_feed() | skip_days: ["Caturday"]}
      errors = errors_for(feed)

      assert has_error?(errors, rule: :format, path: [:skip_days])
    end

    test "lowercase day name returns :format error" do
      feed = %{valid_feed() | skip_days: ["monday"]}
      errors = errors_for(feed)

      assert has_error?(errors, rule: :format, path: [:skip_days])
    end

    test "duplicate skip_days returns :format error" do
      feed = %{valid_feed() | skip_days: ["Monday", "Monday"]}
      errors = errors_for(feed)

      assert has_error?(errors, rule: :format, path: [:skip_days])
    end

    test "empty skip_days passes" do
      assert :ok = Validator.validate(valid_feed())
    end
  end

  # -- Category validation -----------------------------------------------

  describe "category validation" do
    test "valid category passes" do
      feed = %{valid_feed() | categories: [%Category{value: "Tech"}]}
      assert :ok = Validator.validate(feed)
    end

    test "category with empty value returns :required error" do
      feed = %{valid_feed() | categories: [%Category{value: ""}]}
      errors = errors_for(feed)

      assert has_error?(errors, rule: :required, path: [:categories, 0, :value])
    end

    test "category with nil value returns :required error" do
      feed = %{valid_feed() | categories: [struct(Category, %{value: nil})]}
      errors = errors_for(feed)

      assert has_error?(errors, rule: :required, path: [:categories, 0, :value])
    end

    test "item category with empty value returns :required error" do
      item = %Item{title: "T", categories: [%Category{value: ""}]}
      feed = add_item(valid_feed(), item)
      errors = errors_for(feed)

      assert has_error?(errors, rule: :required, path: [:items, 0, :categories, 0, :value])
    end
  end

  # -- Multiple errors ---------------------------------------------------

  describe "multiple errors" do
    test "returns all errors, not just the first" do
      feed =
        struct(Feed, %{
          title: "",
          link: "",
          description: "",
          categories: [],
          skip_hours: [],
          skip_days: [],
          items: [],
          namespaces: %{},
          extensions: %{}
        })

      {:error, errors} = Validator.validate(feed)
      assert length(errors) >= 3
      assert has_error?(errors, rule: :required, path: [:title])
      assert has_error?(errors, rule: :required, path: [:link])
      assert has_error?(errors, rule: :required, path: [:description])
    end

    test "errors across multiple subsystems are all collected" do
      bad_image = %{valid_image() | width: 200, url: ""}
      bad_cloud = %{valid_cloud() | protocol: "grpc"}

      feed = %{
        valid_feed()
        | image: bad_image,
          cloud: bad_cloud,
          items: [%Item{}]
      }

      {:error, errors} = Validator.validate(feed)
      assert has_error?(errors, rule: :required, path: [:image, :url])
      assert has_error?(errors, rule: :range, path: [:image, :width])
      assert has_error?(errors, rule: :format, path: [:cloud, :protocol])
      assert has_error?(errors, rule: :required, path: [:items, 0])
    end
  end

  # -- Error path correctness -------------------------------------------

  describe "error path correctness" do
    test "paths correctly identify nested item positions" do
      bad_enc = %Enclosure{url: "https://example.com/f.mp3", length: -5, type: "audio/mpeg"}

      feed = %{
        valid_feed()
        | items: [
            %Item{title: "Valid"},
            %Item{title: "Valid too"},
            %Item{title: "Bad", enclosure: bad_enc}
          ]
      }

      errors = errors_for(feed)
      assert has_error?(errors, path: [:items, 2, :enclosure, :length])
      refute has_error?(errors, path: [:items, 0, :enclosure, :length])
      refute has_error?(errors, path: [:items, 1, :enclosure, :length])
    end

    test "category paths include item and category index" do
      item = %Item{title: "T", categories: [%Category{value: "OK"}, %Category{value: ""}]}
      feed = add_item(valid_feed(), item)
      errors = errors_for(feed)

      assert has_error?(errors, path: [:items, 0, :categories, 1, :value])
      refute has_error?(errors, path: [:items, 0, :categories, 0, :value])
    end
  end

  # -- Property tests ----------------------------------------------------

  describe "property tests" do
    property "valid feeds always return :ok" do
      check all(feed <- valid_feed_gen()) do
        assert :ok = Validator.validate(feed)
      end
    end

    property "feed with empty title always fails" do
      check all(feed <- valid_feed_gen()) do
        bad_feed = %{feed | title: ""}
        assert {:error, errors} = Validator.validate(bad_feed)
        assert Enum.any?(errors, &(&1.path == [:title] and &1.rule == :required))
      end
    end

    property "feed with invalid skip_hours always fails" do
      check all(
              feed <- valid_feed_gen(),
              bad_hour <- integer(24..100)
            ) do
        bad_feed = %{feed | skip_hours: [bad_hour]}
        assert {:error, errors} = Validator.validate(bad_feed)
        assert Enum.any?(errors, &(&1.path == [:skip_hours] and &1.rule == :range))
      end
    end

    property "feed with invalid skip_days always fails" do
      valid_days = ~w(Monday Tuesday Wednesday Thursday Friday Saturday Sunday)

      bad_day_gen =
        string(:alphanumeric, min_length: 1)
        |> StreamData.filter(&(&1 not in valid_days))

      check all(
              feed <- valid_feed_gen(),
              bad_day <- bad_day_gen
            ) do
        bad_feed = %{feed | skip_days: [bad_day]}
        assert {:error, errors} = Validator.validate(bad_feed)
        assert Enum.any?(errors, &(&1.path == [:skip_days] and &1.rule == :format))
      end
    end

    property "item missing both title and description always fails" do
      check all(feed <- valid_feed_gen()) do
        bad_feed = %{feed | items: [%Item{}]}
        assert {:error, errors} = Validator.validate(bad_feed)
        assert Enum.any?(errors, &(&1.rule == :required and match?([:items, _], &1.path)))
      end
    end

    property "negative ttl always fails" do
      check all(
              feed <- valid_feed_gen(),
              bad_ttl <- positive_integer()
            ) do
        bad_feed = %{feed | ttl: -bad_ttl}
        assert {:error, errors} = Validator.validate(bad_feed)
        assert Enum.any?(errors, &(&1.path == [:ttl] and &1.rule == :type))
      end
    end

    property "image with width > 144 always fails" do
      check all(
              feed <- valid_feed_gen(),
              w <- integer(145..10_000)
            ) do
        image = %{valid_image() | width: w}
        bad_feed = %{feed | image: image}
        assert {:error, errors} = Validator.validate(bad_feed)
        assert Enum.any?(errors, &(&1.path == [:image, :width] and &1.rule == :range))
      end
    end

    property "image with height > 400 always fails" do
      check all(
              feed <- valid_feed_gen(),
              h <- integer(401..10_000)
            ) do
        image = %{valid_image() | height: h}
        bad_feed = %{feed | image: image}
        assert {:error, errors} = Validator.validate(bad_feed)
        assert Enum.any?(errors, &(&1.path == [:image, :height] and &1.rule == :range))
      end
    end
  end

  # -- StreamData generators ---------------------------------------------

  defp valid_feed_gen do
    gen all(
          title <- non_empty_string_gen(),
          description <- non_empty_string_gen()
        ) do
      %Feed{title: title, link: "https://example.com", description: description}
    end
  end

  defp non_empty_string_gen do
    gen all(s <- string(:alphanumeric, min_length: 1, max_length: 50)) do
      s
    end
  end
end
