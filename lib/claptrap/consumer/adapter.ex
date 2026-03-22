defmodule Claptrap.Consumer.Adapter do
  @moduledoc false

  alias Claptrap.Catalog.Source

  @callback mode() :: :pull | :push

  @callback fetch(source :: Source.t()) :: {:ok, [map()]} | {:error, term()}

  @callback ingest(source :: Source.t(), input :: term()) :: {:ok, [map()]} | {:error, term()}

  @callback validate_config(config :: map()) :: :ok | {:error, String.t()}
end
