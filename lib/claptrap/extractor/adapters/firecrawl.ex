defmodule Claptrap.Extractor.Adapters.Firecrawl do
  @moduledoc """
  Firecrawl-backed implementation of `Claptrap.Extractor.Adapter`.

  This adapter calls Firecrawl's scrape API and normalizes the response into
  the extractor contract used by `Claptrap.Extractor.Pipeline`.

  Runtime configuration:

  - `:claptrap, :firecrawl`
    - `:api_key` sent as a Bearer token
    - `:base_url` defaults to `"https://api.firecrawl.dev"`
  - `:claptrap, :firecrawl_req_options`
    - optional `Req` options merged into the request (used by tests and
      transport tuning)

  Request shape:

  - `POST /v1/scrape`
  - JSON body: `%{"url" => url, "formats" => [format]}`

  Return behavior:

  - HTTP `200`: returns `{:ok, result}` if `body["data"][format]` is present
  - HTTP non-`200`: returns `{:error, %{status: status, body: body}}`
  - Transport error from `Req`: returns `{:error, reason}`
  - Missing extracted content for the requested format: returns
    `{:error, %{reason: :missing_content, format: format}}`

  Supported formats are `"markdown"` and `"html"`. The adapter maps these
  formats to content types `"text/markdown"` and `"text/html"` respectively.
  """

  @behaviour Claptrap.Extractor.Adapter

  @impl true
  def supported_formats, do: ["markdown", "html"]

  @impl true
  def extract(url, format, _opts) do
    config = Application.get_env(:claptrap, :firecrawl, [])
    api_key = config[:api_key]
    base_url = config[:base_url] || "https://api.firecrawl.dev"

    req_opts =
      Application.get_env(:claptrap, :firecrawl_req_options, [])
      |> Keyword.merge(
        url: "#{base_url}/v1/scrape",
        json: %{"url" => url, "formats" => [format]},
        headers: [
          {"authorization", "Bearer #{api_key}"}
        ],
        retry: false
      )

    case Req.post(req_opts) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        parse_success(body, format)

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, %{status: status, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_success(body, format) do
    case get_in(body, ["data", format]) do
      nil ->
        {:error, %{reason: :missing_content, format: format}}

      content ->
        {:ok,
         %{
           content: content,
           content_type: content_type(format),
           metadata: body["data"]["metadata"] || %{}
         }}
    end
  end

  defp content_type("markdown"), do: "text/markdown"
  defp content_type("html"), do: "text/html"
  defp content_type(_), do: "application/octet-stream"
end
