defmodule Claptrap.Storage do
  @moduledoc """
  Top-level API for storing and retrieving artifacts.

  Delegates to the configured storage backend (set via application env under
  `{:claptrap, Claptrap.Storage}`). The backend must implement the
  `Claptrap.Storage.Adapter` behaviour.

  ## Key format

  Keys must match `~r/\\A[a-zA-Z0-9][a-zA-Z0-9._-]*\\z/` — alphanumeric start,
  then alphanumeric, dots, underscores, or hyphens. No slashes, spaces, leading
  dots, or path traversal. Invalid keys raise `ArgumentError`.

  ## Stream cleanup

  `read/1` returns `{:ok, stream}` backed by `Stream.resource/3`. If the caller
  never fully consumes the stream, the underlying file handle is closed when the
  stream is garbage collected via the after callback.
  """

  @key_pattern ~r/\A[a-zA-Z0-9][a-zA-Z0-9._-]*\z/
  @prefix_pattern ~r/\A[a-zA-Z0-9._-]*\z/

  def write(key, data) do
    validate_key!(key)
    backend().write(key, data, backend_config())
  end

  def read(key) do
    validate_key!(key)
    backend().read(key, backend_config())
  end

  def delete(key) do
    validate_key!(key)
    backend().delete(key, backend_config())
  end

  def list(prefix \\ "") do
    validate_prefix!(prefix)
    backend().list(prefix, backend_config())
  end

  def exists?(key) do
    validate_key!(key)
    backend().exists?(key, backend_config())
  end

  defp config, do: Application.fetch_env!(:claptrap, __MODULE__)
  defp backend, do: Keyword.fetch!(config(), :backend)

  defp backend_config do
    config() |> Keyword.delete(:backend) |> Map.new()
  end

  defp validate_key!(key) do
    unless Regex.match?(@key_pattern, key) do
      raise ArgumentError, "invalid storage key: #{inspect(key)}"
    end
  end

  defp validate_prefix!(""), do: :ok

  defp validate_prefix!(prefix) do
    unless Regex.match?(@prefix_pattern, prefix) do
      raise ArgumentError, "invalid storage prefix: #{inspect(prefix)}"
    end
  end
end
