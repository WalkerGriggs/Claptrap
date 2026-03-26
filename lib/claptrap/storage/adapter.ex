defmodule Claptrap.Storage.Adapter do
  @moduledoc """
  Behaviour contract for Claptrap storage backends.

  A storage backend is any module that implements this behaviour and
  is wired in through the application configuration:

      config :claptrap, Claptrap.Storage,
        backend: MyBackend,
        # ... backend-specific options ...

  The `Claptrap.Storage` facade resolves the active backend at runtime,
  strips the `:backend` key from the config keyword list, converts the
  remainder to a plain map, and passes that map as the `config` argument
  to every callback. Backend modules are therefore responsible for
  pattern-matching on only the keys they need.

  ## Key contract

  Keys arriving at a backend callback have already been validated by
  `Claptrap.Storage`. They are non-empty strings composed exclusively of
  ASCII letters, digits, dots, hyphens, and underscores, starting with a
  letter or digit. Backends may impose additional constraints (for
  example, path-traversal checks) and must raise `ArgumentError` if a
  key violates those constraints.

  ## Error semantics

  - `:ok` — operation completed successfully (write, delete).
  - `{:ok, value}` — operation completed and returned a value (read,
    list, exists?).
  - `{:error, :not_found}` — the requested key does not exist (read,
    delete). Backends must normalize the underlying filesystem or
    storage `:enoent` into this atom.
  - `{:error, reason}` — any other backend-level failure. `reason` is
    an atom or term that meaningfully describes the failure; backends
    should propagate the atoms returned by the Erlang `:file` module
    unchanged where possible.

  ## Implementing a new backend

  1. Create a module under `Claptrap.Storage.Backends.*`.
  2. Add `@behaviour Claptrap.Storage.Adapter`.
  3. Implement all five callbacks.
  4. Point the application config at the new module.

  No changes to `Claptrap.Storage` or its callers are necessary.
  """

  @typedoc """
  Runtime configuration map for a storage backend.

  Derived from the application environment by stripping the `:backend`
  key and converting the remaining keyword list to a map. Each backend
  documents which keys it requires.
  """
  @type config :: map()

  @doc """
  Writes `data` as the content of the object named `key`.

  `data` is an `Enumerable` of IO data. The backend must consume the
  enumerable sequentially and durably persist the concatenated bytes
  before returning `:ok`. If the object already exists it must be
  overwritten.

  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @callback write(key :: String.t(), data :: Enumerable.t(), config :: config()) ::
              :ok | {:error, term()}

  @doc """
  Opens the object named `key` for reading.

  Returns `{:ok, stream}` where `stream` is a lazy `Enumerable` that
  yields binary chunks when enumerated. The stream must open the
  backing resource lazily and close it after enumeration completes or
  is halted.

  Returns `{:error, :not_found}` when no object exists for `key`.
  Returns `{:error, reason}` for other failures.
  """
  @callback read(key :: String.t(), config :: config()) ::
              {:ok, Enumerable.t()} | {:error, term()}

  @doc """
  Removes the object named `key` from the store.

  Returns `:ok` when the object was successfully deleted.
  Returns `{:error, :not_found}` when no object exists for `key`.
  Returns `{:error, reason}` for other failures.
  """
  @callback delete(key :: String.t(), config :: config()) ::
              :ok | {:error, term()}

  @doc """
  Returns all keys in the store whose names begin with `prefix`.

  When `prefix` is `""`, every key must be included. Keys must be
  returned in ascending lexicographic order.

  Returns `{:ok, [key]}` on success or `{:error, reason}` on failure.
  """
  @callback list(prefix :: String.t(), config :: config()) ::
              {:ok, [String.t()]} | {:error, term()}

  @doc """
  Checks whether an object named `key` currently exists in the store.

  Returns `{:ok, true}` when the object is present and `{:ok, false}`
  when it is absent. Must not return `{:error, :not_found}` for a
  missing key — absence is a valid negative result, not an error.

  Returns `{:error, reason}` only for unexpected backend failures.
  """
  @callback exists?(key :: String.t(), config :: config()) ::
              {:ok, boolean()} | {:error, term()}
end
