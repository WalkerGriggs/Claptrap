defmodule Claptrap.Consumer.Adapters.RSS do
  @moduledoc false

  @behaviour Claptrap.Consumer.Adapter

  import SweetXml

  alias Claptrap.Schemas.Source
  alias Req.Response
  alias Req.TransportError

  @impl true
  def mode, do: :pull

  @impl true
  def validate_config(%{"url" => url}) when is_binary(url) do
    if String.trim(url) == "" do
      {:error, "config requires a non-empty url"}
    else
      :ok
    end
  end

  def validate_config(_), do: {:error, "config requires a non-empty url"}

  @impl true
  def fetch(%Source{} = source) do
    config = source.config || %{}
    :ok = validate_config!(config)

    case Req.get(request_options(config["url"])) do
      {:ok, %Response{status: status, body: body}} when status >= 200 and status < 300 ->
        {:ok, parse_feed!(body)}

      {:ok, %Response{status: status}} when status >= 500 ->
        {:error, {:http_error, status}}

      {:ok, %Response{status: status, body: body}} ->
        raise ArgumentError,
              "rss fetch failed with non-retriable status #{status}: #{inspect(body)}"

      {:error, %TransportError{reason: reason}} ->
        {:error, reason}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def ingest(_source, _input), do: {:error, :unsupported}

  defp request_options(url) do
    :claptrap
    |> Application.get_env(:rss_req_options, [])
    |> Keyword.merge(url: url)
    |> Keyword.put(:retry, false)
  end

  defp validate_config!(config) do
    case validate_config(config) do
      :ok -> :ok
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  defp parse_feed!(body) do
    document = SweetXml.parse(body, dtd: :none)

    case rss_items(document) do
      [] ->
        document
        |> atom_entries()
        |> Enum.map(&normalize_atom_entry/1)

      items ->
        Enum.map(items, &normalize_rss_item/1)
    end
  catch
    :exit, reason ->
      raise ArgumentError, "unable to parse RSS/Atom feed: #{inspect(reason)}"
  end

  defp rss_items(document) do
    xpath(document, ~x"/*[local-name()='rss']/*[local-name()='channel']/*[local-name()='item']"el)
  end

  defp atom_entries(document) do
    xpath(document, ~x"/*[local-name()='feed']/*[local-name()='entry']"el)
  end

  defp normalize_rss_item(item) do
    guid = text(item, ~x"./*[local-name()='guid']/text()"so)
    link = text(item, ~x"./*[local-name()='link']/text()"so)
    title = text(item, ~x"./*[local-name()='title']/text()"so)
    summary = text(item, ~x"./*[local-name()='description']/text()"so)

    author =
      first_present([
        text(item, ~x"./*[local-name()='author']/text()"so),
        text(item, ~x"./*[local-name()='creator']/text()"so)
      ])

    published_raw = text(item, ~x"./*[local-name()='pubDate']/text()"so)
    categories = xpath(item, ~x"./*[local-name()='category']/text()"sl)

    %{
      external_id: external_id([guid, link], [title, published_raw, summary]),
      title: default_title(title),
      summary: blank_to_nil(summary),
      url: blank_to_nil(link),
      author: blank_to_nil(author),
      published_at: parse_published_at(published_raw),
      tags: normalize_tags(categories)
    }
  end

  defp normalize_atom_entry(entry) do
    id = text(entry, ~x"./*[local-name()='id']/text()"so)

    link =
      first_present([
        text(entry, ~x"./*[local-name()='link'][@rel='alternate'][1]/@href"so),
        text(entry, ~x"./*[local-name()='link'][1]/@href"so)
      ])

    title = text(entry, ~x"./*[local-name()='title']/text()"so)

    summary =
      first_present([
        text(entry, ~x"./*[local-name()='summary']/text()"so),
        text(entry, ~x"./*[local-name()='content']/text()"so)
      ])

    author = text(entry, ~x"./*[local-name()='author']/*[local-name()='name']/text()"so)

    published_raw =
      first_present([
        text(entry, ~x"./*[local-name()='published']/text()"so),
        text(entry, ~x"./*[local-name()='updated']/text()"so)
      ])

    categories = xpath(entry, ~x"./*[local-name()='category']/@term"sl)

    %{
      external_id: external_id([id, link], [title, published_raw, summary]),
      title: default_title(title),
      summary: blank_to_nil(summary),
      url: blank_to_nil(link),
      author: blank_to_nil(author),
      published_at: parse_published_at(published_raw),
      tags: normalize_tags(categories)
    }
  end

  defp external_id(primary_candidates, fallback_candidates) do
    case first_present(primary_candidates) do
      nil -> stable_external_id(fallback_candidates)
      value -> value
    end
  end

  defp stable_external_id(candidates) do
    values =
      candidates
      |> Enum.map(&blank_to_nil/1)
      |> Enum.reject(&is_nil/1)

    case values do
      [] ->
        raise ArgumentError, "feed entry is missing a stable identifier"

      present ->
        :crypto.hash(:sha256, Enum.join(present, "|"))
        |> Base.encode16(case: :lower)
    end
  end

  defp default_title(title) do
    case blank_to_nil(title) do
      nil -> "(untitled)"
      value -> value
    end
  end

  defp normalize_tags(values) do
    values
    |> Enum.map(&blank_to_nil/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp first_present(values) do
    Enum.find_value(values, &blank_to_nil/1)
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp text(node, path), do: xpath(node, path)

  defp parse_published_at(nil), do: nil

  defp parse_published_at(value) do
    case blank_to_nil(value) do
      nil ->
        nil

      value ->
        parse_published_at_value(value)
    end
  end

  defp parse_published_at_value(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      _ -> parse_non_iso_datetime(value)
    end
  end

  defp parse_non_iso_datetime(value) do
    case NaiveDateTime.from_iso8601(value) do
      {:ok, naive_datetime} -> DateTime.from_naive!(naive_datetime, "Etc/UTC")
      _ -> parse_http_datetime(value)
    end
  end

  defp parse_http_datetime(value) do
    case parse_rfc822_datetime(value) do
      {:ok, datetime} ->
        datetime

      _ ->
        nil
    end
  end

  defp parse_rfc822_datetime(value) do
    case Regex.run(
           ~r/^(?:\w{3},\s+)?(\d{1,2})\s+(\w{3})\s+(\d{4})\s+(\d{2}):(\d{2})(?::(\d{2}))?\s+(UT|GMT|[+-]\d{4})$/,
           value
         ) do
      [_, day, month, year, hour, minute, second, offset] ->
        build_rfc822_datetime(day, month, year, hour, minute, second, offset)

      _ ->
        :error
    end
  end

  defp build_rfc822_datetime(day, month, year, hour, minute, second, offset) do
    second = if second == "", do: "00", else: second

    with {:ok, month} <- month_number(month),
         {day, ""} <- Integer.parse(day),
         {year, ""} <- Integer.parse(year),
         {hour, ""} <- Integer.parse(hour),
         {minute, ""} <- Integer.parse(minute),
         {second, ""} <- Integer.parse(second),
         {:ok, offset_seconds} <- offset_seconds(offset),
         {:ok, naive_datetime} <- NaiveDateTime.new(year, month, day, hour, minute, second) do
      {:ok,
       naive_datetime
       |> DateTime.from_naive!("Etc/UTC")
       |> DateTime.add(-offset_seconds, :second)}
    else
      _ -> :error
    end
  end

  defp offset_seconds("UT"), do: {:ok, 0}
  defp offset_seconds("GMT"), do: {:ok, 0}

  defp offset_seconds(<<sign::binary-size(1), hours::binary-size(2), minutes::binary-size(2)>>)
       when sign in ["+", "-"] do
    with {hours, ""} <- Integer.parse(hours),
         {minutes, ""} <- Integer.parse(minutes) do
      seconds = hours * 3600 + minutes * 60

      case sign do
        "+" -> {:ok, seconds}
        "-" -> {:ok, -seconds}
      end
    else
      _ -> :error
    end
  end

  defp offset_seconds(_offset), do: :error

  defp month_number("Jan"), do: {:ok, 1}
  defp month_number("Feb"), do: {:ok, 2}
  defp month_number("Mar"), do: {:ok, 3}
  defp month_number("Apr"), do: {:ok, 4}
  defp month_number("May"), do: {:ok, 5}
  defp month_number("Jun"), do: {:ok, 6}
  defp month_number("Jul"), do: {:ok, 7}
  defp month_number("Aug"), do: {:ok, 8}
  defp month_number("Sep"), do: {:ok, 9}
  defp month_number("Oct"), do: {:ok, 10}
  defp month_number("Nov"), do: {:ok, 11}
  defp month_number("Dec"), do: {:ok, 12}
  defp month_number(_month), do: :error
end
