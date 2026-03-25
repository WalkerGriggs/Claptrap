defmodule Claptrap.Extractor.Adapters.Firecrawl do
  @moduledoc false

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
