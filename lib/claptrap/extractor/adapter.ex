defmodule Claptrap.Extractor.Adapter do
  @moduledoc """
  Behaviour contract for extractor adapters.

  The extractor subsystem turns an entry URL into one or more persisted
  artifacts (for example, markdown or html content). Adapter modules implement
  the external fetch and transformation step for a specific extraction provider.

  An adapter receives:

  - `url`: the entry URL to extract content from
  - `format`: the requested artifact format, such as `"markdown"` or `"html"`
  - `opts`: adapter/runtime options passed through by the pipeline

  It must return either:

  - `{:ok, %{content: ..., content_type: ..., metadata: ...}}` when extraction
    succeeds
  - `{:error, reason}` when extraction fails

  The pipeline handles retries and persistence. Adapters should focus on
  provider-specific request and response handling.

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
