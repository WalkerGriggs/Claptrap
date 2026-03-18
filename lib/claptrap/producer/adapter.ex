defmodule Claptrap.Producer.Adapter do
  @moduledoc "Behaviour contract for all sink adapters."

  @callback mode() :: :push | :pull

  @callback push(sink :: %Claptrap.Schemas.Sink{}, entries :: [%Claptrap.Schemas.Entry{}]) ::
              :ok | {:error, term()}

  @callback materialize(
              sink :: %Claptrap.Schemas.Sink{},
              entries :: [%Claptrap.Schemas.Entry{}]
            ) ::
              :ok | {:error, term()}

  @callback validate_config(config :: map()) ::
              :ok | {:error, String.t()}
end
