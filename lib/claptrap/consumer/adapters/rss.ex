defmodule Claptrap.Consumer.Adapters.RSS do
  @moduledoc """
  Pull-mode consumer adapter for RSS 2.0 sources.

  This adapter implements `Claptrap.Consumer.Adapter` for source type `"rss"`.
  It fetches feed XML over HTTP, parses it through `Claptrap.RSS`, and returns
  normalized maps that the worker can persist as catalog entries.

  ## Configuration

  Source config must include:

    * `"url"` - a non-empty binary feed URL

  `validate_config/1` returns `:ok` or `{:error, reason}`. `fetch/1` enforces
  this validation and raises `ArgumentError` if config is invalid.

  ## HTTP behavior

  `fetch/1` sends one request via `Req.get/1`, with options derived from:

    * `Application.get_env(:claptrap, :rss_req_options, [])`
    * the source URL
    * `retry: false` forced for adapter-level control

  Response handling is intentionally split between retryable errors and
  non-retryable failures:

    * `2xx` -> parse and normalize feed items
    * `5xx`, `408`, `429` -> `{:error, {:http_error, status}}`
    * other HTTP statuses -> raise `ArgumentError`
    * transport errors -> `{:error, reason}`

  ## Item normalization

  Each parsed `Claptrap.RSS.Item` becomes:

    * `external_id`
    * `title` (`"(untitled)"` when missing)
    * `summary`
    * `url`
    * `author`
    * `published_at`
    * `tags` (from RSS categories)

  External ID selection is:

    1. non-empty GUID value
    2. non-empty link
    3. SHA-256 hash of available title, publication date, and description

  If none of those fields exist, the adapter raises `ArgumentError` because a
  stable identifier cannot be derived.

  ## Failure model

  This module returns `{:error, reason}` for failures that are expected to be
  retried by `Claptrap.Consumer.Worker`. It raises for invalid config,
  malformed feeds, non-retriable HTTP statuses, and items that cannot be given
  a stable identifier.
  """

  @behaviour Claptrap.Consumer.Adapter

  alias Claptrap.Catalog.Source
  alias Claptrap.RSS
  alias Claptrap.RSS.Item
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
      {:ok, %Response{status: status, body: body}}
      when status >= 200 and status < 300 ->
        parse_feed(body)

      {:ok, %Response{status: status}} when status >= 500 ->
        {:error, {:http_error, status}}

      {:ok, %Response{status: status}} when status in [408, 429] ->
        {:error, {:http_error, status}}

      {:ok, %Response{status: status, body: body}} ->
        raise ArgumentError,
              "rss fetch failed with non-retriable " <>
                "status #{status}: #{inspect(body)}"

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

  defp parse_feed(body) do
    case RSS.parse(body) do
      {:ok, feed} ->
        {:ok, Enum.map(feed.items, &normalize_item/1)}

      {:error, error} ->
        raise ArgumentError,
              "unable to parse RSS feed: #{Exception.message(error)}"
    end
  end

  defp normalize_item(%Item{} = item) do
    %{
      external_id: external_id(item),
      title: item.title || "(untitled)",
      summary: item.description,
      url: item.link,
      author: item.author,
      published_at: item.pub_date,
      tags: Enum.map(item.categories, & &1.value)
    }
  end

  defp external_id(%Item{guid: %{value: value}})
       when is_binary(value) and value != "",
       do: value

  defp external_id(%Item{link: link})
       when is_binary(link) and link != "",
       do: link

  defp external_id(%Item{} = item) do
    values =
      [item.title, format_pub_date(item.pub_date), item.description]
      |> Enum.reject(&is_nil/1)

    case values do
      [] ->
        raise ArgumentError,
              "feed entry is missing a stable identifier"

      present ->
        :crypto.hash(:sha256, Enum.join(present, "|"))
        |> Base.encode16(case: :lower)
    end
  end

  defp format_pub_date(nil), do: nil

  defp format_pub_date(%DateTime{} = dt),
    do: DateTime.to_iso8601(dt)
end
