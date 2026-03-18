defmodule Claptrap.RSS.XmlBackend do
  @moduledoc false

  @callback scan(binary()) :: {:ok, term(), binary()} | {:error, term()}
end
