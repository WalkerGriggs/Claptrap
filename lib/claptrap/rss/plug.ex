defmodule Claptrap.RSS.Plug do
  @moduledoc false

  @behaviour Plug

  import Plug.Conn

  @impl true
  def init(opts) do
    feed_fn = Keyword.fetch!(opts, :feed_fn)
    content_type = Keyword.get(opts, :content_type, "application/rss+xml; charset=utf-8")
    cache_control = Keyword.get(opts, :cache_control, nil)

    %{feed_fn: feed_fn, content_type: content_type, cache_control: cache_control}
  end

  @impl true
  def call(conn, %{feed_fn: feed_fn, content_type: content_type, cache_control: cache_control}) do
    case feed_fn.(conn) do
      %Claptrap.RSS.Feed{} = feed ->
        case Claptrap.RSS.generate(feed) do
          {:ok, xml} ->
            conn
            |> put_resp_content_type(content_type, nil)
            |> maybe_put_cache_control(cache_control)
            |> send_resp(200, xml)
            |> halt()

          {:error, _reason} ->
            conn |> send_resp(500, "Internal Server Error") |> halt()
        end

      {:error, :not_found} ->
        conn |> send_resp(404, "Not Found") |> halt()

      {:error, _reason} ->
        conn |> send_resp(500, "Internal Server Error") |> halt()
    end
  end

  defp maybe_put_cache_control(conn, nil), do: conn

  defp maybe_put_cache_control(conn, value) do
    put_resp_header(conn, "cache-control", value)
  end
end
