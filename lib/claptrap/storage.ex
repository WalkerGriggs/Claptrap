defmodule Claptrap.Storage do
  @moduledoc """
  Public storage boundary for opaque binary data in Claptrap.

  This module is a small facade over a configured storage backend. It is
  responsible for:

  * validating keys and list prefixes before any backend call
  * loading the backend module from application configuration
  * passing the remaining backend-specific configuration through as a map

  The shape of the subsystem is:

      Claptrap.Storage
              |
              v
      Claptrap.Storage.Adapter
              |
              v
      configured backend

  In this repository, the configured backend is
  `Claptrap.Storage.Backends.Local`, which stores data on the local
  filesystem under the configured `root_dir`.

  Storage values are treated as streams of bytes rather than structured
  records. `write/2` accepts an enumerable of chunks, and `read/1`
  returns an enumerable that can be consumed lazily. The module does not
  attach metadata, infer content types, or expose partial reads. It
  offers only the small set of operations implemented today: write, read,
  delete, list, and existence checks.

  ## Key and prefix validation

  The public API accepts a deliberately narrow key format. A key must
  start with an alphanumeric character and may then contain only
  alphanumerics, `.`, `_`, and `-`.

  That means the public API rejects:

  * empty strings
  * path separators such as `/` or `\\`
  * absolute paths and path traversal segments
  * dotfiles such as `.hidden`
  * spaces and null bytes

  `list/1` applies the same character restrictions to prefixes, except
  that the empty string is allowed and means "list everything the backend
  exposes."

  These checks make the facade's keyspace flat. Even though the local
  backend can handle nested filesystem paths when called directly, callers
  that go through `Claptrap.Storage` can only use flat keys.
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
