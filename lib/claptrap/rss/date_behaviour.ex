defmodule Claptrap.RSS.DateBehaviour do
  @moduledoc false

  @callback parse(binary()) :: {:ok, DateTime.t()} | {:error, :invalid_date}
  @callback format(DateTime.t()) :: binary()
end
