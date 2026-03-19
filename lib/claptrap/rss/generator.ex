defmodule Claptrap.RSS.Generator do
  @moduledoc false

  alias Claptrap.RSS.{Feed, GenerateError}

  @spec generate(Feed.t(), keyword()) :: {:ok, binary()} | {:error, GenerateError.t()}
  def generate(_feed, _opts \\ []) do
    Process.get({__MODULE__, :impl}, {:error, %GenerateError{reason: :not_implemented, message: "not implemented"}})
  end
end
