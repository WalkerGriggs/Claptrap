defmodule Claptrap.Storage.Adapter do
  @moduledoc false

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
