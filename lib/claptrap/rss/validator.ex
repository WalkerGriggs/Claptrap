defmodule Claptrap.RSS.Validator do
  @moduledoc false

  alias Claptrap.RSS.{Category, Cloud, Enclosure, Feed, Guid, Image, Item, ValidationError}

  @valid_days ~w(Monday Tuesday Wednesday Thursday Friday Saturday Sunday)
  @valid_cloud_protocols ~w(xml-rpc soap http-post)

  # Absolute URI: valid scheme (RFC 3986) + ":" + non-empty remainder (opaque or hier-part).
  # Accepts mailto:, news:, https://, etc.; rejects host-only strings like "example.com".
  @absolute_uri_pattern ~r/\A[a-zA-Z][a-zA-Z0-9+\-.]*:.+\z/

  @spec validate(Feed.t()) :: :ok | {:error, [ValidationError.t()]}
  def validate(%Feed{} = feed) do
    errors =
      []
      |> validate_channel(feed)
      |> validate_categories(feed.categories, [:categories])
      |> validate_items(feed)
      |> validate_image(feed)
      |> validate_cloud(feed)
      |> validate_skip_hours(feed)
      |> validate_skip_days(feed)
      |> Enum.reverse()

    case errors do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  # -- Channel -----------------------------------------------------------

  defp validate_channel(errors, feed) do
    errors
    |> require_non_empty_string(feed.title, [:title])
    |> require_non_empty_string(feed.link, [:link])
    |> require_non_empty_string(feed.description, [:description])
    |> validate_url(feed.link, [:link])
    |> validate_ttl(feed.ttl)
  end

  defp validate_ttl(errors, nil), do: errors
  defp validate_ttl(errors, ttl) when is_integer(ttl) and ttl >= 0, do: errors

  defp validate_ttl(errors, _ttl) do
    [error("ttl must be a non-negative integer", [:ttl], :type) | errors]
  end

  # -- Items --------------------------------------------------------------

  defp validate_items(errors, feed) do
    feed.items
    |> Enum.with_index()
    |> Enum.reduce(errors, fn {item, index}, acc ->
      validate_item(acc, item, index)
    end)
  end

  defp validate_item(errors, %Item{} = item, index) do
    errors
    |> validate_item_title_or_description(item, index)
    |> validate_item_link(item, index)
    |> validate_enclosure(item.enclosure, index)
    |> validate_guid(item.guid, index)
    |> validate_categories(item.categories, [:items, index, :categories])
  end

  defp validate_item_title_or_description(errors, item, index) do
    has_title = non_empty_string?(item.title)
    has_description = non_empty_string?(item.description)

    if has_title or has_description do
      errors
    else
      [
        error(
          "item must have at least one of title or description",
          [:items, index],
          :required
        )
        | errors
      ]
    end
  end

  defp validate_item_link(errors, %Item{link: nil}, _index), do: errors

  defp validate_item_link(errors, %Item{link: link}, index),
    do: validate_url(errors, link, [:items, index, :link])

  # -- Enclosure ----------------------------------------------------------

  defp validate_enclosure(errors, nil, _index), do: errors

  defp validate_enclosure(errors, %Enclosure{} = enc, index) do
    path = [:items, index, :enclosure]

    errors
    |> require_non_empty_string(enc.url, path ++ [:url])
    |> validate_url(enc.url, path ++ [:url])
    |> require_non_empty_string(enc.type, path ++ [:type])
    |> validate_enclosure_length(enc.length, path ++ [:length])
  end

  defp validate_enclosure_length(errors, length, _path)
       when is_integer(length) and length >= 0,
       do: errors

  defp validate_enclosure_length(errors, _length, path) do
    [error("enclosure length must be a non-negative integer", path, :type) | errors]
  end

  # -- GUID ---------------------------------------------------------------

  defp validate_guid(errors, nil, _index), do: errors

  defp validate_guid(errors, %Guid{is_perma_link: true, value: value}, index) do
    if url?(value) do
      errors
    else
      [
        error(
          "guid with is_perma_link=true should be a URL",
          [:items, index, :guid, :value],
          :format
        )
        | errors
      ]
    end
  end

  defp validate_guid(errors, %Guid{}, _index), do: errors

  # -- Categories ---------------------------------------------------------

  defp validate_categories(errors, categories, base_path) do
    categories
    |> Enum.with_index()
    |> Enum.reduce(errors, fn {cat, index}, acc ->
      validate_category(acc, cat, base_path ++ [index])
    end)
  end

  defp validate_category(errors, %Category{value: value}, path) do
    require_non_empty_string(errors, value, path ++ [:value])
  end

  # -- Image --------------------------------------------------------------

  defp validate_image(errors, %Feed{image: nil}), do: errors

  defp validate_image(errors, %Feed{image: %Image{} = image}) do
    errors
    |> require_non_empty_string(image.url, [:image, :url])
    |> require_non_empty_string(image.title, [:image, :title])
    |> require_non_empty_string(image.link, [:image, :link])
    |> validate_url(image.url, [:image, :url])
    |> validate_url(image.link, [:image, :link])
    |> validate_image_width(image.width)
    |> validate_image_height(image.height)
  end

  defp validate_image_width(errors, nil), do: errors
  defp validate_image_width(errors, w) when is_integer(w) and w >= 0 and w <= 144, do: errors

  defp validate_image_width(errors, _w) do
    [error("image width must be between 0 and 144", [:image, :width], :range) | errors]
  end

  defp validate_image_height(errors, nil), do: errors
  defp validate_image_height(errors, h) when is_integer(h) and h >= 0 and h <= 400, do: errors

  defp validate_image_height(errors, _h) do
    [error("image height must be between 0 and 400", [:image, :height], :range) | errors]
  end

  # -- Cloud --------------------------------------------------------------

  defp validate_cloud(errors, %Feed{cloud: nil}), do: errors

  defp validate_cloud(errors, %Feed{cloud: %Cloud{} = cloud}) do
    errors
    |> require_non_empty_string(cloud.domain, [:cloud, :domain])
    |> require_non_empty_string(cloud.path, [:cloud, :path])
    |> require_non_empty_string(cloud.register_procedure, [:cloud, :register_procedure])
    |> validate_cloud_port(cloud.port)
    |> validate_cloud_protocol(cloud.protocol)
  end

  defp validate_cloud_port(errors, port) when is_integer(port) and port >= 0, do: errors

  defp validate_cloud_port(errors, _port) do
    [error("cloud port must be a non-negative integer", [:cloud, :port], :type) | errors]
  end

  defp validate_cloud_protocol(errors, protocol) when protocol in @valid_cloud_protocols,
    do: errors

  defp validate_cloud_protocol(errors, _protocol) do
    [
      error(
        "cloud protocol must be one of: #{Enum.join(@valid_cloud_protocols, ", ")}",
        [:cloud, :protocol],
        :format
      )
      | errors
    ]
  end

  # -- Skip hours ---------------------------------------------------------

  defp validate_skip_hours(errors, %Feed{skip_hours: hours}) do
    errors
    |> validate_skip_hour_values(hours)
    |> validate_no_duplicates(hours, [:skip_hours], "skip_hours")
  end

  defp validate_skip_hour_values(errors, hours) do
    Enum.reduce(hours, errors, fn hour, acc ->
      if is_integer(hour) and hour >= 0 and hour <= 23 do
        acc
      else
        [
          error(
            "skip_hours value must be an integer between 0 and 23, got: #{inspect(hour)}",
            [:skip_hours],
            :range
          )
          | acc
        ]
      end
    end)
  end

  # -- Skip days ----------------------------------------------------------

  defp validate_skip_days(errors, %Feed{skip_days: days}) do
    errors
    |> validate_skip_day_values(days)
    |> validate_no_duplicates(days, [:skip_days], "skip_days")
  end

  defp validate_skip_day_values(errors, days) do
    Enum.reduce(days, errors, fn day, acc ->
      if day in @valid_days do
        acc
      else
        [
          error(
            "skip_days value must be a valid day name, got: #{inspect(day)}",
            [:skip_days],
            :format
          )
          | acc
        ]
      end
    end)
  end

  # -- Shared helpers -----------------------------------------------------

  defp validate_no_duplicates(errors, values, path, field_name) do
    if length(values) == length(Enum.uniq(values)) do
      errors
    else
      [error("#{field_name} must not contain duplicates", path, :format) | errors]
    end
  end

  defp require_non_empty_string(errors, value, path) do
    if non_empty_string?(value) do
      errors
    else
      field = List.last(path)
      [error("#{field} is required and must be a non-empty string", path, :required) | errors]
    end
  end

  defp validate_url(errors, value, path) do
    if non_empty_string?(value) and not url?(value) do
      field = List.last(path)
      [error("#{field} must begin with a valid URI scheme", path, :format) | errors]
    else
      errors
    end
  end

  defp non_empty_string?(value) when is_binary(value) and byte_size(value) > 0, do: true
  defp non_empty_string?(_), do: false

  defp url?(value) when is_binary(value), do: Regex.match?(@absolute_uri_pattern, value)
  defp url?(_), do: false

  defp error(message, path, rule) do
    %ValidationError{message: message, path: path, rule: rule}
  end
end
