defmodule Claptrap.Storage do
  @moduledoc """
  Backend-agnostic facade for Claptrap's blob storage layer.

  `Claptrap.Storage` is the single public interface through which the rest
  of the application reads, writes, lists, and deletes opaque binary
  objects. It delegates every operation to a configurable backend module
  that implements the `Claptrap.Storage.Adapter` behaviour. The active
  backend and its runtime options are drawn from the application
  environment at call time:

      config :claptrap, Claptrap.Storage,
        backend: Claptrap.Storage.Backends.Local,
        root_dir: "/var/claptrap/storage"

  The `:backend` key names the module. All other keys in the keyword list
  are forwarded to the backend as a plain map so that each implementation
  can declare its own required fields.

  ## Keys

  A *key* is the unique identifier for a stored object. Keys must satisfy
  the following rules:

  - At least one character long.
  - Start with an ASCII letter or digit (`[a-zA-Z0-9]`).
  - Contain only ASCII letters, digits, dots (`.`), hyphens (`-`), and
    underscores (`_`).

  These constraints deliberately exclude path-separator characters,
  leading dots, whitespace, and null bytes. The rules apply uniformly
  across all backends so that callers never need to think about backend-
  specific escaping or path traversal risks.

  Any function that accepts a `key` argument will raise `ArgumentError`
  if the key does not match `~r/\\A[a-zA-Z0-9][a-zA-Z0-9._-]*\\z/`.

  ## Prefixes

  `list/1` accepts an optional prefix string. An empty string (`""`)
  matches every key. A non-empty prefix follows the same character-set
  rules as a key. Passing a prefix that begins with a dot or contains
  disallowed characters raises `ArgumentError`.

  ## Error handling

  All functions return `:ok` or `{:ok, value}` on success. Failures
  propagate as `{:error, reason}` where `reason` is a backend-defined
  term. The special atom `:not_found` is returned (rather than an error
  tuple) when a key is absent in `read/1` and `delete/1`; `exists?/1`
  never returns an error for a missing key — it returns `{:ok, false}`.

  ## Adding a new backend

  Implement `Claptrap.Storage.Adapter` and point the configuration at the
  new module. No changes to this facade or its callers are required.
  """

  @key_pattern ~r/\A[a-zA-Z0-9][a-zA-Z0-9._-]*\z/
  @prefix_pattern ~r/\A[a-zA-Z0-9][a-zA-Z0-9._-]*\z/

  @doc """
  Writes `data` to the object identified by `key`.

  `data` is any `Enumerable` whose elements are `IO` data (binaries or
  iodata). The backend consumes the enumerable once and stores the
  concatenated bytes as a single object. Passing a list of strings,
  a `Stream`, or a `File.Stream` are all valid.

  Returns `:ok` on success or `{:error, reason}` if the backend
  encounters an error.

  Raises `ArgumentError` if `key` is invalid.

  ## Examples

      :ok = Claptrap.Storage.write("report.json", [~s({"ok":true})])

      :ok = Claptrap.Storage.write(
        "dump.bin",
        File.stream!("/tmp/source.bin", [], 65_536)
      )
  """
  def write(key, data) do
    validate_key!(key)
    backend().write(key, data, backend_config())
  end

  @doc """
  Reads the object identified by `key` as a lazy stream of binary chunks.

  Returns `{:ok, stream}` where `stream` is an `Enumerable` that yields
  binary chunks as it is consumed. The stream is opened lazily: the
  backing resource is not accessed until the caller begins enumeration.
  This allows large objects to be piped through a pipeline without loading
  the full contents into memory.

  Returns `{:error, :not_found}` when no object exists for `key`.
  Returns `{:error, reason}` for other backend errors.

  Raises `ArgumentError` if `key` is invalid.

  ## Examples

      {:ok, stream} = Claptrap.Storage.read("report.json")
      content = Enum.join(stream)
  """
  def read(key) do
    validate_key!(key)
    backend().read(key, backend_config())
  end

  @doc """
  Deletes the object identified by `key`.

  Returns `:ok` on success or `{:error, :not_found}` when no object
  exists for that key. Other backend errors are returned as
  `{:error, reason}`.

  Raises `ArgumentError` if `key` is invalid.

  ## Examples

      :ok = Claptrap.Storage.delete("report.json")
  """
  def delete(key) do
    validate_key!(key)
    backend().delete(key, backend_config())
  end

  @doc """
  Lists all keys that begin with `prefix`.

  When `prefix` is omitted or `""`, every key in the store is returned.
  Keys are returned in ascending lexicographic order. The returned list
  contains only leaf-level keys; intermediate path components (if any)
  are not included.

  Returns `{:ok, [key]}` on success or `{:error, reason}` on failure.

  Raises `ArgumentError` if `prefix` is non-empty and does not satisfy
  the prefix character-set rules.

  ## Examples

      {:ok, all_keys} = Claptrap.Storage.list()
      # => {:ok, ["artifact.txt", "report.json"]}

      {:ok, reports} = Claptrap.Storage.list("report")
      # => {:ok, ["report.json"]}
  """
  def list(prefix \\ "") do
    validate_prefix!(prefix)
    backend().list(prefix, backend_config())
  end

  @doc """
  Checks whether an object identified by `key` currently exists.

  Returns `{:ok, true}` when the object is present and `{:ok, false}`
  when it is not. This call never returns `{:error, :not_found}`; a
  missing key is a valid negative result, not an error condition.

  Returns `{:error, reason}` only for unexpected backend failures.

  Raises `ArgumentError` if `key` is invalid.

  ## Examples

      {:ok, true}  = Claptrap.Storage.exists?("report.json")
      {:ok, false} = Claptrap.Storage.exists?("missing.json")
  """
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
