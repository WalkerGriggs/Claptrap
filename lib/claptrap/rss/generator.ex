defmodule Claptrap.RSS.Generator do
  @moduledoc false

  alias Claptrap.RSS.GenerateError

  @spec generate(term(), keyword()) :: {:error, GenerateError.t()}
  def generate(_feed, _opts \\ []) do
    {:error, %GenerateError{reason: :not_implemented, message: "not implemented", path: []}}
  end
end
