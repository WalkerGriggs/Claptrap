defmodule Claptrap.Storage.Adapter do
  @moduledoc """
  Behaviour for storage backends used by `Claptrap.Storage`.

  Each callback receives a `config` map built from application environment
  for `Claptrap.Storage`, excluding only the `:backend` key. Backends declare
  what keys that map must contain (for example `root_dir` for the local
  filesystem implementation).

  ## Callback contracts

  `write/3` accepts an enumerable of iodata chunks and should persist them in
  order for the given key. It returns `:ok` or `{:error, reason}`.

  `read/2` returns `{:ok, enumerable}` on success. The enumerable may be a
  lazy stream; callers should reduce it to read the object. A missing object
  is typically reported as `{:error, :not_found}`, but the exact convention
  is defined by each backend.

  `delete/2` removes the object for the key or returns an error (including
  `{:error, :not_found}` when the implementation treats a missing key as an
  error).

  `list/2` returns `{:ok, [String.t()]}` of keys matching the given prefix
  according to that backend's rules, or `{:error, reason}`.

  `exists?/2` returns `{:ok, true}` or `{:ok, false}` on success, or
  `{:error, reason}` when the check cannot be completed.
  """

  @type config :: map()

  @callback write(
              key :: String.t(),
              data :: Enumerable.t(),
              config :: config()
            ) :: :ok | {:error, term()}

  @callback read(key :: String.t(), config :: config()) ::
              {:ok, Enumerable.t()} | {:error, term()}

  @callback delete(key :: String.t(), config :: config()) ::
              :ok | {:error, term()}

  @callback list(prefix :: String.t(), config :: config()) ::
              {:ok, [String.t()]} | {:error, term()}

  @callback exists?(key :: String.t(), config :: config()) ::
              {:ok, boolean()} | {:error, term()}
end
