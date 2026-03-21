defmodule Claptrap.RSS.Generator do
  @moduledoc false

  alias Claptrap.RSS.{
    Category,
    Cloud,
    Date,
    Enclosure,
    Feed,
    GenerateError,
    Guid,
    Image,
    Item,
    Source,
    TextInput,
    Validator
  }

  @spec generate(Feed.t(), keyword()) :: {:ok, binary()} | {:error, GenerateError.t()}
  def generate(%Feed{} = feed, opts \\ []) do
    validate? = Keyword.get(opts, :validate, true)

    with :ok <- maybe_validate(feed, validate?) do
      do_generate(feed, opts)
    end
  end

  defp maybe_validate(_feed, false), do: :ok

  defp maybe_validate(feed, true) do
    case Validator.validate(feed) do
      :ok ->
        :ok

      {:error, _errors} ->
        {:error,
         %GenerateError{
           reason: :validation_failed,
           message: "feed validation failed",
           path: []
         }}
    end
  end

  defp do_generate(feed, opts) do
    date_mod = Keyword.get(opts, :date_module, Date)
    uri_to_prefix = invert_namespaces(feed.namespaces)

    iodata = [
      ~c"<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
      rss_open(feed.namespaces),
      ~c"<channel>",
      channel_elements(feed, date_mod, uri_to_prefix),
      Enum.map(feed.items, &item_element(&1, date_mod, uri_to_prefix)),
      ~c"</channel>",
      ~c"</rss>"
    ]

    {:ok, IO.iodata_to_binary(iodata)}
  end

  # --- RSS open tag with namespace declarations ---

  defp rss_open(namespaces) do
    ns_attrs =
      namespaces
      |> Enum.sort()
      |> Enum.map(fn {prefix, uri} ->
        [~c" xmlns:", prefix, ~c"=\"", xml_escape(uri), ~c"\""]
      end)

    [~c"<rss version=\"2.0\"", ns_attrs, ~c">"]
  end

  # --- Channel elements ---

  defp channel_elements(feed, date_mod, uri_to_prefix) do
    [
      text_el("title", feed.title),
      text_el("link", feed.link),
      description_el(feed.description),
      optional_text_el("language", feed.language),
      optional_text_el("copyright", feed.copyright),
      optional_text_el("managingEditor", feed.managing_editor),
      optional_text_el("webMaster", feed.web_master),
      optional_date_el("pubDate", feed.pub_date, date_mod),
      optional_date_el("lastBuildDate", feed.last_build_date, date_mod),
      optional_text_el("generator", feed.generator),
      optional_text_el("docs", feed.docs),
      optional_text_el("ttl", if(feed.ttl, do: Integer.to_string(feed.ttl))),
      optional_text_el("rating", feed.rating),
      categories_elements(feed.categories),
      cloud_element(feed.cloud),
      image_element(feed.image),
      text_input_element(feed.text_input),
      skip_hours_element(feed.skip_hours),
      skip_days_element(feed.skip_days),
      extensions_elements(feed.extensions, uri_to_prefix)
    ]
  end

  # --- Item element ---

  defp item_element(%Item{} = item, date_mod, uri_to_prefix) do
    [
      ~c"<item>",
      optional_text_el("title", item.title),
      optional_text_el("link", item.link),
      optional_description_el(item.description),
      optional_text_el("author", item.author),
      optional_text_el("comments", item.comments),
      optional_date_el("pubDate", item.pub_date, date_mod),
      enclosure_element(item.enclosure),
      guid_element(item.guid),
      source_element(item.source),
      categories_elements(item.categories),
      extensions_elements(item.extensions, uri_to_prefix),
      ~c"</item>"
    ]
  end

  # --- Simple text elements ---

  defp text_el(tag, value) do
    [~c"<", tag, ~c">", xml_escape(value), ~c"</", tag, ~c">"]
  end

  defp optional_text_el(_tag, nil), do: []

  defp optional_text_el(tag, value) do
    text_el(tag, value)
  end

  # --- Description with CDATA ---

  defp description_el(value) do
    [~c"<description>", maybe_cdata(value), ~c"</description>"]
  end

  defp optional_description_el(nil), do: []
  defp optional_description_el(value), do: description_el(value)

  defp maybe_cdata(text) when is_binary(text) do
    cond do
      not needs_cdata?(text) -> xml_escape(text)
      String.contains?(text, "]]>") -> xml_escape(text)
      true -> [~c"<![CDATA[", text, ~c"]]>"]
    end
  end

  defp needs_cdata?(text), do: String.contains?(text, "<") or String.contains?(text, "&")

  # --- Date elements ---

  defp optional_date_el(_tag, nil, _date_mod), do: []

  defp optional_date_el(tag, %DateTime{} = dt, date_mod) do
    text_el(tag, date_mod.format(dt))
  end

  # --- Categories ---

  defp categories_elements(categories) do
    Enum.map(categories, &category_element/1)
  end

  defp category_element(%Category{value: value, domain: nil}) do
    [~c"<category>", xml_escape(value), ~c"</category>"]
  end

  defp category_element(%Category{value: value, domain: domain}) do
    [~c"<category domain=\"", xml_escape(domain), ~c"\">", xml_escape(value), ~c"</category>"]
  end

  # --- Cloud (self-closing, attributes only) ---

  defp cloud_element(nil), do: []

  defp cloud_element(%Cloud{} = cloud) do
    [
      ~c"<cloud",
      ~c" domain=\"",
      xml_escape(cloud.domain),
      ~c"\"",
      ~c" port=\"",
      Integer.to_string(cloud.port),
      ~c"\"",
      ~c" path=\"",
      xml_escape(cloud.path),
      ~c"\"",
      ~c" registerProcedure=\"",
      xml_escape(cloud.register_procedure),
      ~c"\"",
      ~c" protocol=\"",
      xml_escape(cloud.protocol),
      ~c"\"",
      ~c"/>"
    ]
  end

  # --- Image ---

  defp image_element(nil), do: []

  defp image_element(%Image{} = img) do
    [
      ~c"<image>",
      text_el("url", img.url),
      text_el("title", img.title),
      text_el("link", img.link),
      optional_text_el("width", if(img.width, do: Integer.to_string(img.width))),
      optional_text_el("height", if(img.height, do: Integer.to_string(img.height))),
      optional_text_el("description", img.description),
      ~c"</image>"
    ]
  end

  # --- TextInput ---

  defp text_input_element(nil), do: []

  defp text_input_element(%TextInput{} = ti) do
    [
      ~c"<textInput>",
      text_el("title", ti.title),
      text_el("description", ti.description),
      text_el("name", ti.name),
      text_el("link", ti.link),
      ~c"</textInput>"
    ]
  end

  # --- Enclosure (self-closing, attributes only) ---

  defp enclosure_element(nil), do: []

  defp enclosure_element(%Enclosure{} = enc) do
    [
      ~c"<enclosure",
      ~c" url=\"",
      xml_escape(enc.url),
      ~c"\"",
      ~c" length=\"",
      Integer.to_string(enc.length),
      ~c"\"",
      ~c" type=\"",
      xml_escape(enc.type),
      ~c"\"",
      ~c"/>"
    ]
  end

  # --- Guid ---

  defp guid_element(nil), do: []

  defp guid_element(%Guid{} = guid) do
    perma = if guid.is_perma_link, do: "true", else: "false"

    [
      ~c"<guid isPermaLink=\"",
      perma,
      ~c"\">",
      xml_escape(guid.value),
      ~c"</guid>"
    ]
  end

  # --- Source ---

  defp source_element(nil), do: []

  defp source_element(%Source{} = src) do
    [
      ~c"<source url=\"",
      xml_escape(src.url),
      ~c"\">",
      xml_escape(src.value),
      ~c"</source>"
    ]
  end

  # --- Skip hours / days ---

  defp skip_hours_element([]), do: []

  defp skip_hours_element(hours) do
    [
      ~c"<skipHours>",
      Enum.map(hours, fn h -> text_el("hour", Integer.to_string(h)) end),
      ~c"</skipHours>"
    ]
  end

  defp skip_days_element([]), do: []

  defp skip_days_element(days) do
    [
      ~c"<skipDays>",
      Enum.map(days, fn d -> text_el("day", d) end),
      ~c"</skipDays>"
    ]
  end

  # --- Extension elements ---

  defp extensions_elements(extensions, _uri_to_prefix) when map_size(extensions) == 0,
    do: []

  defp extensions_elements(extensions, uri_to_prefix) do
    extensions
    |> Enum.sort()
    |> Enum.flat_map(fn {uri, elements} ->
      prefix = Map.get(uri_to_prefix, uri, uri)
      Enum.map(elements, &extension_element(&1, prefix))
    end)
  end

  defp extension_element(%{name: name, attrs: attrs, value: value}, prefix) do
    tag = "#{prefix}:#{name}"
    attr_iodata = extension_attrs(attrs)

    case value do
      children when is_list(children) ->
        [~c"<", tag, attr_iodata, ~c">", Enum.map(children, &extension_element(&1, prefix)), ~c"</", tag, ~c">"]

      text when is_binary(text) and byte_size(text) > 0 ->
        [~c"<", tag, attr_iodata, ~c">", maybe_cdata(text), ~c"</", tag, ~c">"]

      _ ->
        [~c"<", tag, attr_iodata, ~c"/>"]
    end
  end

  defp extension_attrs(attrs) when map_size(attrs) == 0, do: []

  defp extension_attrs(attrs) do
    attrs
    |> Enum.sort()
    |> Enum.map(fn {k, v} -> [~c" ", k, ~c"=\"", xml_escape(v), ~c"\""] end)
  end

  # --- Namespace inversion ---

  defp invert_namespaces(namespaces) do
    Map.new(namespaces, fn {prefix, uri} -> {uri, prefix} end)
  end

  # --- XML escaping ---

  defp xml_escape(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
