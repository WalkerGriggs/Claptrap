defmodule Claptrap.Storage.Adapter do
  @moduledoc """
  Behaviour for storage backends used by `Claptrap.Storage`.

  A storage backend is responsible for persisting and retrieving opaque binary
  data addressed by string keys. The behaviour intentionally stays small and
  mirrors the public operations exposed by `Claptrap.Storage`:

  * `write/3` stores an enumerable of binary chunks under a key
  * `read/2` returns a readable enumerable for a key
  * `delete/2` removes a key
  * `list/2` returns keys visible to the backend for a prefix
  * `exists?/2` reports whether a key is present

  The backend receives its configuration as a plain map. `Claptrap.Storage`
  builds that map from application configuration by taking the configured
  keyword list for the storage subsystem and removing the `:backend` entry.

  ## Contract notes

  This behaviour defines the currently implemented contract, not an idealized
  one:

  * keys and prefixes are plain strings
  * stored values are streamed through enumerables rather than loaded into a
    single binary by the facade
  * backend-specific error reasons are allowed and passed through unchanged,
    except where a backend normalizes them itself

  The facade is free to apply additional validation before a backend is
  called. In the current codebase, `Claptrap.Storage` restricts callers to a
  flat keyspace, while `Claptrap.Storage.Backends.Local` can support nested
  relative paths when used directly.
  """

  @type config :: map()

  @callback write(key :: String.t(), data :: Enumerable.t(), config :: config()) ::
              :ok | {:error, term()}

  @callback read(key :: String.t(), config :: config()) ::
              {:ok, Enumerable.t()} | {:error, term()}

  @callback delete(key :: String.t(), config :: config()) ::
              :ok | {:error, term()}

  @callback list(prefix :: String.t(), config :: config()) ::
              {:ok, [String.t()]} | {:error, term()}

  @callback exists?(key :: String.t(), config :: config()) ::
              {:ok, boolean()} | {:error, term()}
end
