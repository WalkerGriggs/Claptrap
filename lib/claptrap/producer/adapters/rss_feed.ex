defmodule Claptrap.Producer.Adapters.RssFeed do
  @moduledoc """
  RSS 2.0 feed adapter. Materializes entries into XML stored in ETS.

  ETS table `:claptrap_rss_feeds` is owned by `Producer.Supervisor` and must
  be created before this adapter is used.
  """

  @behaviour Claptrap.Producer.Adapter

  alias Claptrap.Catalog
  alias Claptrap.Schemas.{Entry, Sink}

  @ets_table :claptrap_rss_feeds
  @default_max_entries 50

  @impl true
  def mode, do: :pull

  @impl true
  def push(_sink, _entries), do: {:error, "RssFeed adapter does not support push"}

  @impl true
  def materialize(%Sink{} = sink, _entries) do
    limit = get_in(sink.config, ["max_entries"]) || @default_max_entries
    entries = Catalog.entries_for_sink(sink.id, limit: limit)
    xml = build_rss(sink, entries)
    :ets.insert(@ets_table, {sink.id, {xml, DateTime.utc_now()}})
    :ok
  end

  @impl true
  def validate_config(config) when is_map(config) do
    case Map.fetch(config, "description") do
      {:ok, desc} when is_binary(desc) and byte_size(desc) > 0 -> :ok
      {:ok, _} -> {:error, "description must be a non-empty string"}
      :error -> {:error, "description is required"}
    end
  end

  def validate_config(_), do: {:error, "config must be a map"}

  # Private

  defp build_rss(sink, entries) do
    last_build = rfc2822(DateTime.utc_now())
    description = get_in(sink.config, ["description"]) || ""
    items = Enum.map(entries, &build_item/1)

    IO.iodata_to_binary([
      ~s(<?xml version="1.0" encoding="UTF-8"?>\n),
      ~s(<rss version="2.0">\n),
      ~s(  <channel>\n),
      ~s(    <title>),
      escape(sink.name),
      ~s(</title>\n),
      ~s(    <description>),
      escape(description),
      ~s(</description>\n),
      ~s(    <lastBuildDate>),
      last_build,
      ~s(</lastBuildDate>\n),
      items,
      ~s(  </channel>\n),
      ~s(</rss>\n)
    ])
  end

  defp build_item(%Entry{} = entry) do
    pub_date = if entry.published_at, do: rfc2822(entry.published_at), else: ""

    IO.iodata_to_binary([
      ~s(    <item>\n),
      ~s(      <title>),
      escape(entry.title || ""),
      ~s(</title>\n),
      ~s(      <link>),
      escape(entry.url || ""),
      ~s(</link>\n),
      ~s(      <description>),
      escape(entry.summary || ""),
      ~s(</description>\n),
      ~s(      <author>),
      escape(entry.author || ""),
      ~s(</author>\n),
      ~s(      <pubDate>),
      pub_date,
      ~s(</pubDate>\n),
      ~s(      <guid isPermaLink="false">),
      entry.id,
      ~s(</guid>\n),
      ~s(    </item>\n)
    ])
  end

  defp escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  @days ~w(Mon Tue Wed Thu Fri Sat Sun)
  @months ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

  defp rfc2822(%DateTime{} = dt) do
    day_name = Enum.at(@days, Date.day_of_week(DateTime.to_date(dt)) - 1)
    month_name = Enum.at(@months, dt.month - 1)

    :io_lib.format(
      "~s, ~2..0B ~s ~4..0B ~2..0B:~2..0B:~2..0B +0000",
      [day_name, dt.day, month_name, dt.year, dt.hour, dt.minute, dt.second]
    )
    |> IO.iodata_to_binary()
  end
end
