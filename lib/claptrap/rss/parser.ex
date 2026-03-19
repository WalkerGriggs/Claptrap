defmodule Claptrap.RSS.Parser do
  @moduledoc false

  alias Claptrap.RSS.ParseError

  @spec parse(binary(), keyword()) :: {:error, ParseError.t()}
  def parse(_xml, _opts \\ []) do
    {:error, %ParseError{reason: :not_implemented, message: "not implemented"}}
  end
end
