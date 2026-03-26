defmodule Claptrap.Storage do
  @moduledoc """
  Application-facing API for storing and retrieving binary blobs by string
  key.

  This module is a thin facade over a configurable backend. It reads
  `Application.fetch_env!(:claptrap, Claptrap.Storage)`, takes the `:backend`
  value as the module that implements `Claptrap.Storage.Adapter`, and passes
  all other keyword options to that backend as a map (without the `:backend`
  key). For example, `config.exs` sets
  `backend: Claptrap.Storage.Backends.Local` and `root_dir: ...` for the
  default local filesystem backend.

  ## Operations

  Callers use `write/2`, `read/1`, `delete/1`, `list/1`, and `exists?/1`.
  Return shapes and error atoms come from the active backend; the facade does
  not reinterpret them beyond key and prefix validation.

  ## Keys and prefixes

  Keys must match a restricted pattern: a non-empty string whose first
  character is alphanumeric and whose remaining characters are only letters,
  digits, dot, underscore, or hyphen. Invalid keys raise `ArgumentError`
  before the backend runs. This rejects path separators, spaces, and other
  characters that would be unsafe or ambiguous for storage paths.

  For `list/1`, the optional prefix follows the same pattern as keys, except
  the empty string is allowed and means "no prefix filter" for backends that
  support listing.
  """

  @key_pattern ~r/\A[a-zA-Z0-9][a-zA-Z0-9._-]*\z/
  @prefix_pattern ~r/\A[a-zA-Z0-9][a-zA-Z0-9._-]*\z/

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

    :ok
  end

  defp validate_prefix!(""), do: :ok

  defp validate_prefix!(prefix) do
    unless Regex.match?(@prefix_pattern, prefix) do
      raise ArgumentError, "invalid storage prefix: #{inspect(prefix)}"
    end

    :ok
  end
end
