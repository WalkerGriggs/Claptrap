defmodule Claptrap.RSS.Parser do
  @moduledoc false

  alias Claptrap.RSS.{Category, Cloud, Enclosure, Feed, Guid, Image, Item, Source, TextInput}
  alias Claptrap.RSS.{Date, ParseError}

  @type xml_element :: tuple()

  @camel_to_snake %{
    "managingEditor" => :managing_editor,
    "webMaster" => :web_master,
    "pubDate" => :pub_date,
    "lastBuildDate" => :last_build_date,
    "skipHours" => :skip_hours,
    "skipDays" => :skip_days,
    "textInput" => :text_input,
    "isPermaLink" => :is_perma_link
  }

  @channel_scalars ~w(title link description language copyright generator docs rating)
  @channel_date_fields ~w(pubDate lastBuildDate)
  @channel_camel_scalars ~w(managingEditor webMaster)

  # Dialyzer cannot see through the MapSet opaque type when built from module
  # attribute literals; the warnings on extract_extensions and its helpers are
  # false positives.
  @dialyzer [
    {:nowarn_function, extract_extensions: 2},
    {:nowarn_function, extension_element_filter: 2},
    {:nowarn_function, if_channel_or_item: 1}
  ]

  @spec parse(binary(), keyword()) :: {:ok, Feed.t()} | {:error, ParseError.t()}
  def parse(xml, opts \\ [])

  def parse(xml, _opts) when not is_binary(xml) or xml == "" do
    {:error, %ParseError{reason: :invalid_xml, message: "input must be a non-empty binary"}}
  end

  def parse(xml, opts) do
    strict = Keyword.get(opts, :strict, false)
    xml_backend = Keyword.get(opts, :xml_backend, nil)
    date_module = Keyword.get(opts, :date_module, Date)

    with {:ok, doc, _rest} <- scan_xml(xml, xml_backend),
         {:ok, rss_element} <- find_rss_element(doc),
         {:ok, channel_element} <- find_channel(rss_element, strict) do
      namespaces = extract_namespaces(rss_element)
      build_feed(channel_element, rss_element, namespaces, strict, date_module)
    end
  end

  defp scan_xml(xml, nil), do: default_scan(xml)
  defp scan_xml(xml, backend), do: backend.scan(xml)

  defp default_scan(xml_binary) do
    # Use :binary.bin_to_list/1 instead of String.to_charlist/1
    # so xmerl receives raw UTF-8 bytes rather than Unicode
    # codepoints. xmerl handles UTF-8 decoding internally
    # and rejects codepoints above 127 passed as integers.
    charlist =
      try do
        :binary.bin_to_list(xml_binary)
      rescue
        _ -> nil
      end

    if is_nil(charlist) do
      {:error, %ParseError{reason: :invalid_xml, message: "failed to parse XML"}}
    else
      try do
        {doc, _rest} = :xmerl_scan.string(charlist, space: :normalize, quiet: true)
        {:ok, doc, ""}
      rescue
        _e -> {:error, %ParseError{reason: :invalid_xml, message: "failed to parse XML"}}
      catch
        :exit, _reason -> {:error, %ParseError{reason: :invalid_xml, message: "failed to parse XML"}}
      end
    end
  end

  defp find_rss_element(doc) do
    case element_name(doc) do
      "rss" ->
        {:ok, doc}

      _ ->
        case find_child_element(doc, "rss") do
          nil -> {:error, %ParseError{reason: :missing_channel, message: "no <rss> element found"}}
          rss -> {:ok, rss}
        end
    end
  end

  defp find_channel(rss_element, strict) do
    case find_child_element(rss_element, "channel") do
      nil when strict ->
        {:error, %ParseError{reason: :missing_channel, message: "no <channel> element found inside <rss>"}}

      nil ->
        {:error, %ParseError{reason: :missing_channel, message: "no <channel> element found inside <rss>"}}

      channel ->
        {:ok, channel}
    end
  end

  defp build_feed(channel, rss_element, namespaces, strict, date_module) do
    children = child_elements(channel)
    version = get_attribute(rss_element, "version")

    scalars = extract_scalars(children, strict)
    dates = extract_dates(children, strict, date_module)
    ttl = extract_ttl(children)
    image = extract_image(children)
    text_input = extract_text_input(children)
    cloud = extract_cloud(children)
    categories = extract_categories(children)
    skip_hours = extract_skip_hours(children)
    skip_days = extract_skip_days(children)
    items = extract_items(children, namespaces, strict, date_module)
    channel_extensions = extract_extensions(children, namespaces)

    with :ok <- validate_required_scalars(scalars, strict),
         :ok <- validate_dates(dates, strict) do
      feed = %Feed{
        title: scalars[:title] || "",
        link: scalars[:link] || "",
        description: scalars[:description] || "",
        language: scalars[:language],
        copyright: scalars[:copyright],
        managing_editor: scalars[:managing_editor],
        web_master: scalars[:web_master],
        pub_date: dates[:pub_date],
        last_build_date: dates[:last_build_date],
        generator: scalars[:generator],
        docs: scalars[:docs],
        ttl: ttl,
        rating: scalars[:rating],
        image: image,
        text_input: text_input,
        cloud: cloud,
        categories: categories,
        skip_hours: skip_hours,
        skip_days: skip_days,
        items: items,
        namespaces: maybe_add_version(namespaces, version),
        extensions: channel_extensions
      }

      {:ok, feed}
    end
  end

  defp maybe_add_version(namespaces, nil), do: namespaces
  defp maybe_add_version(namespaces, _version), do: namespaces

  defp validate_required_scalars(scalars, true) do
    missing =
      ~w(title link description)a
      |> Enum.filter(fn key -> is_nil(scalars[key]) or scalars[key] == "" end)

    case missing do
      [] ->
        :ok

      [field | _] ->
        {:error,
         %ParseError{
           reason: :missing_required_field,
           message: "missing required channel element: #{field}"
         }}
    end
  end

  defp validate_required_scalars(_scalars, false), do: :ok

  defp validate_dates(dates, true) do
    date_error =
      Enum.find(dates, fn
        {_key, {:date_error, _raw}} -> true
        _ -> false
      end)

    case date_error do
      {_key, {:date_error, raw}} ->
        {:error, %ParseError{reason: :malformed_date, message: "malformed date: #{raw}"}}

      nil ->
        :ok
    end
  end

  defp validate_dates(_dates, false), do: :ok

  defp extract_scalars(children, _strict) do
    acc = %{}

    Enum.reduce(children, acc, fn el, acc ->
      name = element_name(el)

      cond do
        name in @channel_scalars ->
          key = String.to_atom(name)
          Map.put_new(acc, key, text_content(el))

        name in @channel_camel_scalars ->
          key = Map.fetch!(@camel_to_snake, name)
          Map.put_new(acc, key, text_content(el))

        true ->
          acc
      end
    end)
  end

  defp extract_dates(children, strict, date_module) do
    Enum.reduce(children, %{}, fn el, acc ->
      name = element_name(el)
      reduce_date_element(acc, name, el, strict, date_module)
    end)
  end

  defp reduce_date_element(acc, name, el, strict, date_module) do
    if name in @channel_date_fields do
      key = Map.fetch!(@camel_to_snake, name)
      put_date_if_absent(acc, key, el, strict, date_module)
    else
      acc
    end
  end

  defp put_date_if_absent(acc, key, el, strict, date_module) do
    if Map.has_key?(acc, key) do
      acc
    else
      Map.put(acc, key, parse_date(text_content(el), strict, date_module))
    end
  end

  defp parse_date(nil, _strict, _date_module), do: nil
  defp parse_date("", _strict, _date_module), do: nil

  defp parse_date(raw, true, date_module) do
    case date_module.parse(raw) do
      {:ok, dt} -> dt
      {:error, _} -> {:date_error, raw}
    end
  end

  defp parse_date(raw, false, date_module) do
    case date_module.parse(raw) do
      {:ok, dt} -> dt
      {:error, _} -> nil
    end
  end

  defp extract_ttl(children) do
    case find_first(children, "ttl") do
      nil ->
        nil

      el ->
        case text_content(el) do
          nil -> nil
          raw -> parse_integer(raw)
        end
    end
  end

  defp parse_integer(s) do
    case Integer.parse(String.trim(s)) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp extract_image(children) do
    case find_first(children, "image") do
      nil ->
        nil

      el ->
        img_children = child_elements(el)
        url = text_of(img_children, "url")
        title = text_of(img_children, "title")
        link = text_of(img_children, "link")

        if url do
          %Image{
            url: url,
            title: title || "",
            link: link || "",
            width: optional_int(img_children, "width"),
            height: optional_int(img_children, "height"),
            description: text_of(img_children, "description")
          }
        else
          nil
        end
    end
  end

  defp extract_text_input(children) do
    case find_first(children, "textInput") do
      nil ->
        nil

      el ->
        ti_children = child_elements(el)
        title = text_of(ti_children, "title")
        description = text_of(ti_children, "description")
        name = text_of(ti_children, "name")
        link = text_of(ti_children, "link")

        if title && name do
          %TextInput{
            title: title,
            description: description || "",
            name: name,
            link: link || ""
          }
        else
          nil
        end
    end
  end

  defp extract_cloud(children) do
    case find_first(children, "cloud") do
      nil ->
        nil

      el ->
        domain = get_attribute(el, "domain")
        port = get_attribute(el, "port")
        path = get_attribute(el, "path")
        register_procedure = get_attribute(el, "registerProcedure")
        protocol = get_attribute(el, "protocol")

        if domain && port && path && register_procedure && protocol do
          %Cloud{
            domain: domain,
            port: parse_integer(port) || 0,
            path: path,
            register_procedure: register_procedure,
            protocol: protocol
          }
        else
          nil
        end
    end
  end

  defp extract_categories(children) do
    children
    |> Enum.filter(&(element_name(&1) == "category"))
    |> Enum.map(fn el ->
      %Category{
        value: text_content(el) || "",
        domain: get_attribute(el, "domain")
      }
    end)
  end

  defp extract_skip_hours(children) do
    case find_first(children, "skipHours") do
      nil ->
        []

      el ->
        el
        |> child_elements()
        |> Enum.filter(&(element_name(&1) == "hour"))
        |> Enum.map(&text_content/1)
        |> Enum.map(&parse_integer/1)
        |> Enum.reject(&is_nil/1)
    end
  end

  defp extract_skip_days(children) do
    case find_first(children, "skipDays") do
      nil ->
        []

      el ->
        el
        |> child_elements()
        |> Enum.filter(&(element_name(&1) == "day"))
        |> Enum.map(&text_content/1)
        |> Enum.reject(&is_nil/1)
    end
  end

  defp extract_items(children, feed_namespaces, strict, date_module) do
    children
    |> Enum.filter(&(element_name(&1) == "item"))
    |> Enum.map(&parse_item(&1, feed_namespaces, strict, date_module))
  end

  defp parse_item(el, feed_namespaces, strict, date_module) do
    children = child_elements(el)

    pub_date_raw = text_of(children, "pubDate")

    pub_date =
      if pub_date_raw do
        parsed = parse_date(pub_date_raw, strict, date_module)

        case parsed do
          {:date_error, _} -> nil
          other -> other
        end
      else
        nil
      end

    item_namespaces = extract_element_namespaces(el)
    merged_namespaces = Map.merge(feed_namespaces, item_namespaces)
    extensions = extract_extensions(children, merged_namespaces)

    %Item{
      title: text_of(children, "title"),
      link: text_of(children, "link"),
      description: text_of(children, "description"),
      author: text_of(children, "author"),
      comments: text_of(children, "comments"),
      pub_date: pub_date,
      enclosure: extract_enclosure(children),
      guid: extract_guid(children),
      source: extract_source(children),
      categories: extract_categories(children),
      extensions: extensions
    }
  end

  defp extract_enclosure(children) do
    case find_first(children, "enclosure") do
      nil ->
        nil

      el ->
        url = get_attribute(el, "url")
        length = get_attribute(el, "length")
        type = get_attribute(el, "type")

        if url do
          %Enclosure{
            url: url,
            length: (length && parse_integer(length)) || 0,
            type: type || ""
          }
        else
          nil
        end
    end
  end

  defp extract_guid(children) do
    case find_first(children, "guid") do
      nil ->
        nil

      el ->
        value = text_content(el)
        is_perma_link_attr = get_attribute(el, "isPermaLink")

        is_perma_link =
          case is_perma_link_attr do
            "false" -> false
            _ -> true
          end

        if value do
          %Guid{value: value, is_perma_link: is_perma_link}
        else
          nil
        end
    end
  end

  defp extract_source(children) do
    case find_first(children, "source") do
      nil ->
        nil

      el ->
        value = text_content(el)
        url = get_attribute(el, "url")

        if value && url do
          %Source{value: value, url: url}
        else
          nil
        end
    end
  end

  # --- Namespace and extension extraction ---

  defp extract_namespaces(element) do
    element
    |> get_xmerl_attributes()
    |> Enum.reduce(%{}, &reduce_namespace_attr/2)
  end

  defp extract_element_namespaces(element) do
    element
    |> get_xmerl_attributes()
    |> Enum.reduce(%{}, &reduce_namespace_attr/2)
  end

  defp reduce_namespace_attr({:xmlAttribute, name, _, _, _, _, _, _, value, _}, acc) do
    case to_string(name) do
      "xmlns:" <> prefix -> Map.put(acc, prefix, to_string(value))
      _ -> acc
    end
  end

  defp reduce_namespace_attr(_, acc), do: acc

  defp get_xmerl_attributes(element) when is_tuple(element) do
    case element do
      {:xmlElement, _, _, _, _, _, _, attrs, _, _, _, _} when is_list(attrs) -> attrs
      _ -> []
    end
  end

  defp get_xmerl_attributes(_), do: []

  @known_channel_tags MapSet.new(~w(title link description language copyright managingEditor webMaster
                          pubDate lastBuildDate generator docs ttl rating image textInput cloud
                          category skipHours skipDays item))

  @known_item_tags MapSet.new(~w(title link description author comments pubDate enclosure guid source category))

  defp extract_extensions(children, namespaces) do
    known_tags = if_channel_or_item(children)

    children
    |> Enum.reject(&extension_element_filter(&1, known_tags))
    |> Enum.reduce(%{}, &reduce_extension_element(&1, &2, namespaces))
  end

  @spec extension_element_filter(term(), MapSet.t(String.t())) :: boolean()
  defp extension_element_filter(el, known_tags) do
    name = element_name(el)
    MapSet.member?(known_tags, name) or not String.contains?(name, ":")
  end

  defp reduce_extension_element(el, acc, namespaces) do
    case String.split(element_name(el), ":", parts: 2) do
      [prefix, local_name] ->
        uri = Map.get(namespaces, prefix, prefix)
        ext = build_extension_element(local_name, el)
        Map.update(acc, uri, [ext], fn existing -> existing ++ [ext] end)

      _ ->
        acc
    end
  end

  @spec if_channel_or_item(list()) :: MapSet.t(String.t())
  defp if_channel_or_item(children) do
    has_items = Enum.any?(children, fn el -> element_name(el) == "item" end)

    if has_items do
      @known_channel_tags
    else
      @known_item_tags
    end
  end

  defp build_extension_element(local_name, el) do
    attrs = el |> get_xmerl_attributes() |> Enum.reduce(%{}, &reduce_extension_attr/2)
    value = build_extension_value(el)
    %{name: local_name, attrs: attrs, value: value}
  end

  defp reduce_extension_attr({:xmlAttribute, name, _, _, _, _, _, _, value, _}, acc) do
    name_str = to_string(name)

    if String.starts_with?(name_str, "xmlns") do
      acc
    else
      Map.put(acc, name_str, to_string(value))
    end
  end

  defp reduce_extension_attr(_, acc), do: acc

  defp build_extension_value(el) do
    case child_elements(el) do
      [] -> text_content(el)
      children -> Enum.map(children, &build_child_extension/1)
    end
  end

  defp build_child_extension(child) do
    local =
      case String.split(element_name(child), ":", parts: 2) do
        [_prefix, name] -> name
        _ -> element_name(child)
      end

    build_extension_element(local, child)
  end

  # --- xmerl DOM traversal helpers ---

  defp element_name(element) when is_tuple(element) do
    case element do
      {:xmlElement, name, _, _, _, _, _, _, _, _, _, _} ->
        name
        |> to_string()
        |> normalize_element_name()

      _ ->
        ""
    end
  end

  defp element_name(_), do: ""

  defp normalize_element_name(name) do
    case String.split(name, ":", parts: 2) do
      [_prefix, local] when local != "" -> name
      _ -> name
    end
  end

  defp child_elements(element) when is_tuple(element) do
    case element do
      {:xmlElement, _, _, _, _, _, _, _, content, _, _, _} when is_list(content) ->
        Enum.filter(content, &match?({:xmlElement, _, _, _, _, _, _, _, _, _, _, _}, &1))

      _ ->
        []
    end
  end

  defp child_elements(_), do: []

  defp text_content(element) when is_tuple(element) do
    case element do
      {:xmlElement, _, _, _, _, _, _, _, content, _, _, _} when is_list(content) ->
        text =
          content
          |> Enum.map_join("", &extract_text_node/1)
          |> String.trim()

        if text == "", do: nil, else: text

      _ ->
        nil
    end
  end

  defp text_content(_), do: nil

  defp extract_text_node({:xmlText, _, _, _, value, _}) do
    to_string(value)
  end

  defp extract_text_node({:xmlCdata, _, _, _, value, _}) do
    to_string(value)
  end

  defp extract_text_node(_), do: ""

  defp find_child_element(element, tag_name) do
    element
    |> child_elements()
    |> find_first_by_name(tag_name)
  end

  defp find_first(children, tag_name) do
    find_first_by_name(children, tag_name)
  end

  defp find_first_by_name(elements, tag_name) do
    Enum.find(elements, fn el -> element_name(el) == tag_name end)
  end

  defp text_of(children, tag_name) do
    case find_first(children, tag_name) do
      nil -> nil
      el -> text_content(el)
    end
  end

  defp optional_int(children, tag_name) do
    case text_of(children, tag_name) do
      nil -> nil
      raw -> parse_integer(raw)
    end
  end

  defp get_attribute(element, attr_name) when is_tuple(element) do
    element
    |> get_xmerl_attributes()
    |> Enum.find_value(fn
      {:xmlAttribute, name, _, _, _, _, _, _, value, _} ->
        if to_string(name) == attr_name, do: to_string(value)

      _ ->
        nil
    end)
  end

  defp get_attribute(_, _), do: nil
end
