defmodule Claptrap.Consumer.Adapters.RSS do
  @moduledoc "Pull-mode adapter for RSS 2.0 and Atom feeds."

  @behaviour Claptrap.Consumer.Adapter

  import SweetXml

  @impl true
  def mode, do: :pull

  @impl true
  def validate_config(%{"url" => url}) when is_binary(url) and url != "", do: :ok
  def validate_config(_), do: {:error, "config must include a non-empty \"url\" key"}

  @impl true
  def fetch(%{config: config} = _source) do
    case validate_config(config) do
      {:error, reason} -> raise ArgumentError, reason
      :ok -> do_fetch(config["url"])
    end
  end

  @impl true
  def ingest(_source, _input), do: {:error, :not_supported}

  # Private

  defp do_fetch(url) do
    req_opts = [url: url, decode_body: false] ++ test_plug_opts()

    case Req.request(req_opts) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, parse_feed(body)}

      {:ok, %{status: status}} when status >= 500 ->
        {:error, {:http_error, status}}

      {:ok, %{status: status}} ->
        raise RuntimeError, "unexpected HTTP status #{status} fetching #{url}"

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp test_plug_opts do
    case Application.get_env(:claptrap, :req_test_plug) do
      nil -> []
      plug -> [plug: plug]
    end
  end

  defp parse_feed(body) when is_binary(body) do
    doc = parse(body)

    cond do
      xpath(doc, ~x"//channel"o) -> parse_rss(doc)
      xpath(doc, ~x"//feed"o) -> parse_atom(doc)
      true -> raise RuntimeError, "unrecognized feed format"
    end
  end

  defp parse_feed(body) when is_map(body) do
    # Req auto-parsed — shouldn't happen for XML but guard anyway
    raise RuntimeError, "unexpected parsed body type: #{inspect(body)}"
  end

  defp parse_rss(doc) do
    doc
    |> xpath(~x"//channel/item"l)
    |> Enum.map(&normalize_rss_item/1)
  end

  defp parse_atom(doc) do
    doc
    |> xpath(~x"//feed/entry"l)
    |> Enum.map(&normalize_atom_entry/1)
  end

  defp normalize_rss_item(item) do
    guid = xpath(item, ~x"guid/text()"s)
    link = xpath(item, ~x"link/text()"s)
    external_id = if guid != "", do: guid, else: link

    title = xpath(item, ~x"title/text()"s)
    title = if title != "", do: title, else: "(untitled)"

    %{
      external_id: external_id,
      title: title,
      summary: nilify(xpath(item, ~x"description/text()"s)),
      url: nilify(link),
      author: nilify_first([
        xpath(item, ~x"author/text()"s),
        xpath(item, ~x"*[local-name()='creator']/text()"s)
      ]),
      published_at: parse_datetime(xpath(item, ~x"pubDate/text()"s)),
      tags: xpath(item, ~x"category/text()"ls),
      status: "unread"
    }
  end

  defp normalize_atom_entry(entry) do
    id = xpath(entry, ~x"id/text()"s)
    link = xpath(entry, ~x"link/@href"s)
    external_id = if id != "", do: id, else: link

    title = xpath(entry, ~x"title/text()"s)
    title = if title != "", do: title, else: "(untitled)"

    summary =
      nilify(xpath(entry, ~x"summary/text()"s)) ||
        nilify(xpath(entry, ~x"content/text()"s))

    %{
      external_id: external_id,
      title: title,
      summary: summary,
      url: nilify(link),
      author: nilify(xpath(entry, ~x"author/name/text()"s)),
      published_at: parse_datetime(xpath(entry, ~x"published/text()"s)),
      tags: xpath(entry, ~x"category/@term"ls),
      status: "unread"
    }
  end

  defp nilify(""), do: nil
  defp nilify(value), do: value

  defp nilify_first(values) do
    Enum.find_value(values, &nilify/1)
  end

  defp parse_datetime(""), do: nil

  defp parse_datetime(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} ->
        dt

      _ ->
        parse_rfc1123(str)
    end
  end

  # Parses RFC 1123 / RFC 822 dates common in RSS feeds.
  # Example: "Mon, 01 Jan 2024 12:00:00 +0000"
  @months %{
    "Jan" => 1, "Feb" => 2, "Mar" => 3, "Apr" => 4,
    "May" => 5, "Jun" => 6, "Jul" => 7, "Aug" => 8,
    "Sep" => 9, "Oct" => 10, "Nov" => 11, "Dec" => 12
  }

  defp parse_rfc1123(str) do
    regex = ~r/\w+,\s+(\d+)\s+(\w+)\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})\s+(\+\d{4}|-\d{4}|GMT|UTC|Z)/

    case Regex.run(regex, str) do
      [_, day, month_str, year, hour, minute, second, tz_str] ->
        month = Map.get(@months, month_str)

        if month do
          offset = parse_tz_offset(tz_str)
          naive = NaiveDateTime.new!(
            String.to_integer(year),
            month,
            String.to_integer(day),
            String.to_integer(hour),
            String.to_integer(minute),
            String.to_integer(second)
          )
          DateTime.from_naive!(naive, "Etc/UTC")
          |> DateTime.add(-offset, :second)
        end

      _ ->
        nil
    end
  end

  defp parse_tz_offset(tz) when tz in ["GMT", "UTC", "Z"], do: 0

  defp parse_tz_offset(<<"+" :: binary, rest :: binary>>) do
    {hours, minutes} = String.split_at(rest, 2)
    String.to_integer(hours) * 3600 + String.to_integer(minutes) * 60
  end

  defp parse_tz_offset(<<"-" :: binary, rest :: binary>>) do
    {hours, minutes} = String.split_at(rest, 2)
    -(String.to_integer(hours) * 3600 + String.to_integer(minutes) * 60)
  end

  defp parse_tz_offset(_), do: 0
end
