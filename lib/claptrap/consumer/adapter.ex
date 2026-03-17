defmodule Claptrap.Consumer.Adapter do
  @moduledoc "Behaviour that all consumer adapters must implement."

  @callback mode() :: :pull | :push

  @callback fetch(source :: Claptrap.Schemas.Source.t()) ::
              {:ok, [map()]} | {:error, term()}

  @callback ingest(source :: Claptrap.Schemas.Source.t(), input :: term()) ::
              {:ok, [map()]} | {:error, term()}

  @callback validate_config(config :: map()) :: :ok | {:error, String.t()}
end
