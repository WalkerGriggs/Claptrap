defmodule Claptrap.Producer.Adapter do
  @moduledoc """
  Behaviour contract for all sink adapters.

  Adapters are either push-based (deliver entries to an external destination)
  or pull-based (materialize a stored representation for later retrieval).
  """

  alias Claptrap.Schemas.{Entry, Sink}

  @doc "Declares whether the adapter pushes or materializes."
  @callback mode() :: :push | :pull

  @doc "Delivers entries to an external destination (push sinks)."
  @callback push(sink :: Sink.t(), entries :: [Entry.t()]) :: :ok | {:error, term()}

  @doc "Updates a stored representation for later retrieval (pull sinks)."
  @callback materialize(sink :: Sink.t(), entries :: [Entry.t()]) :: :ok | {:error, term()}

  @doc "Validates sink-specific config at create/update time."
  @callback validate_config(config :: map()) :: :ok | {:error, String.t()}
end
