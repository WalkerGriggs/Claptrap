defmodule Claptrap.RSS.Parser do
  @moduledoc false

  alias Claptrap.RSS.{Feed, ParseError}

  @spec parse(binary(), keyword()) :: {:ok, Feed.t()} | {:error, ParseError.t()}
  def parse(_xml, _opts \\ []) do
    Process.get({__MODULE__, :impl}, {:error, %ParseError{reason: :not_implemented, message: "not implemented"}})
  end
end
