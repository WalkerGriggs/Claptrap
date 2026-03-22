defmodule Claptrap.Producer.Adapter do
  @moduledoc "Behaviour contract for all sink adapters."

  @callback mode() :: :push | :pull

  @callback push(sink :: %Claptrap.Catalog.Sink{}, entries :: [%Claptrap.Catalog.Entry{}]) ::
              :ok | {:error, term()}

  @callback materialize(
              sink :: %Claptrap.Catalog.Sink{},
              entries :: [%Claptrap.Catalog.Entry{}]
            ) ::
              :ok | {:error, term()}

  @callback validate_config(config :: map()) ::
              :ok | {:error, String.t()}
end
