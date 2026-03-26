defmodule Claptrap.Extractor.Pipeline do
  @moduledoc """
  Executes extraction for entries and persists resulting artifacts.

  `Claptrap.Extractor.Router` dispatches each extractable entry to this module.
  For each configured format, the pipeline:

  1. looks up the adapter configured for that format
  2. calls the adapter with retry + exponential backoff
  3. upserts the artifact into the catalog

  The function `extract_and_store/3` is intentionally resilient at the batch
  level:

  - missing adapter for one format logs a warning and continues
  - extraction failure for one format logs an error and continues
  - persistence failure logs an error and continues

  This means one failing format does not block other formats for the same
  entry.

  ## Inputs

  - `entry`: map-like struct that must include `id` and `url`
  - `formats`: list of formats to extract, for example `["markdown", "html"]`
  - `config`: runtime options, with these keys used by the pipeline:
    - `:adapters` map of `"format" => AdapterModule`
    - `:max_attempts` (default `5`)
    - `:base_backoff_ms` (default `500`)
    - `:max_backoff_ms` (default `30_000`)
    - any additional keys are forwarded to adapters in `opts`

  Entries with `nil` or empty URLs are treated as non-extractable and return
  immediately.

  ## Retry behavior

  Adapter calls are retried until success or `max_attempts` is reached.
  Backoff is exponential with jitter and an upper bound:

      delay_ms =
        min(base_backoff_ms * 2^(attempt - 1) + random(1..200),
            max_backoff_ms)

  ## Persistence behavior

  Successful extraction results are written through `Claptrap.Catalog` using
  `create_artifact/1`. The catalog layer performs upsert semantics keyed by
  `{entry_id, format}`, so repeated extraction updates an existing artifact
  instead of creating duplicates.
  """

  require Logger

  alias Claptrap.Catalog

  @max_attempts 5
  @base_backoff_ms 500
  @max_backoff_ms 30_000

  def extract_and_store(%{url: nil}, _formats, _config), do: :ok
  def extract_and_store(%{url: ""}, _formats, _config), do: :ok

  def extract_and_store(entry, formats, config) do
    adapters = config[:adapters] || %{}
    opts = Map.drop(config, [:adapters, :formats])

    for format <- formats do
      case Map.get(adapters, format) do
        nil ->
          Logger.warning("No adapter configured for format #{inspect(format)}")

        adapter ->
          extract_format(adapter, entry, format, opts)
      end
    end

    :ok
  end

  defp extract_format(adapter, entry, format, opts) do
    max = opts[:max_attempts] || @max_attempts

    case attempt_extract(adapter, entry.url, format, opts, 1, max) do
      {:ok, result} ->
        case Catalog.create_artifact(%{
               entry_id: entry.id,
               format: format,
               content: result.content,
               content_type: result.content_type,
               byte_size: byte_size(result.content),
               extractor: adapter_name(adapter),
               metadata: result.metadata
             }) do
          {:ok, _artifact} ->
            :ok

          {:error, changeset} ->
            Logger.error(
              "Failed to persist artifact for entry=#{entry.id} " <>
                "format=#{format}: #{inspect(changeset)}"
            )
        end

      {:error, reason} ->
        Logger.error(
          "Extraction failed for entry=#{entry.id} " <>
            "format=#{format}: #{inspect(reason)}"
        )
    end
  end

  defp attempt_extract(adapter, url, format, opts, attempt, max) do
    case adapter.extract(url, format, opts) do
      {:ok, _result} = success ->
        success

      {:error, _reason} = error when attempt >= max ->
        error

      {:error, _reason} ->
        backoff = compute_backoff(attempt, opts)
        Process.sleep(backoff)
        attempt_extract(adapter, url, format, opts, attempt + 1, max)
    end
  end

  defp compute_backoff(attempt, opts) do
    base = opts[:base_backoff_ms] || @base_backoff_ms
    max_ms = opts[:max_backoff_ms] || @max_backoff_ms
    min(base * Integer.pow(2, attempt - 1) + :rand.uniform(200), max_ms)
  end

  defp adapter_name(adapter) do
    adapter
    |> Module.split()
    |> List.last()
    |> String.downcase()
  end
end
