defmodule Claptrap.Extractor.Adapter do
  @moduledoc """
  Behaviour for extractor adapters.

  An extractor takes a URL and a desired output format,
  and returns the extracted content. Adapters handle the
  specifics of how content is fetched and transformed.

  ## Implementing an adapter

      defmodule MyAdapter do
        @behaviour Claptrap.Extractor.Adapter

        @impl true
        def extract(url, format, opts) do
          # fetch and transform content...
          {:ok, %{content: "...", content_type: "text/markdown", metadata: %{}}}
        end

        @impl true
        def supported_formats, do: ["markdown"]
      end
  """

  @type extract_result :: %{
          content: binary(),
          content_type: String.t(),
          metadata: map()
        }

  @callback extract(url :: String.t(), format :: String.t(), opts :: map()) ::
              {:ok, extract_result()} | {:error, term()}

  @callback supported_formats() :: [String.t()]
end
