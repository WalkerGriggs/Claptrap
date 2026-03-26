defmodule Claptrap.Storage.Adapter do
  @moduledoc """
  Behaviour that all storage backends must implement.

  `Claptrap.Storage` delegates every persistence operation to a
  backend module that adopts this behaviour. The behaviour defines
  five callbacks covering the complete lifecycle of a stored blob:
  writing, reading, deleting, listing, and existence checks.

  ## Callback contract

  Every callback receives a `config` map whose keys are determined
  by the application configuration for `Claptrap.Storage`, minus
  the `:backend` key (which selects the adapter itself). This
  allows each backend to require its own configuration shape
  without changing the public API. For example, the local
  filesystem backend requires a `:root_dir` key, while a future
  cloud backend might require bucket names and credentials.

  ## Data streaming

  The `write/3` callback accepts `data` as an `Enumerable.t()` of
  iodata chunks. Backends should consume the enumerable
  incrementally rather than collecting it into a single binary, so
  that large payloads do not need to be held entirely in memory.

  The `read/2` callback returns `{:ok, Enumerable.t()}` on
  success. The returned enumerable should be lazy (for example, a
  `Stream`) so that callers can process data chunk by chunk.

  ## Error handling

  All callbacks return tagged tuples on failure rather than
  raising. The `term()` in `{:error, term()}` is backend-specific
  but should be an atom when possible (for example, `:not_found`
  or `:enoent`) to support pattern matching.

  ## Implementing a new backend

  To add a storage backend:

    1. Create a module under `Claptrap.Storage.Backends`.
    2. Add `@behaviour Claptrap.Storage.Adapter`.
    3. Implement all five callbacks.
    4. Set the new module as `:backend` in the application
       configuration for `Claptrap.Storage`.
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
