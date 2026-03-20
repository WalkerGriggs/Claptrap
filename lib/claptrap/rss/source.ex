defmodule Claptrap.RSS.Source do
  @moduledoc false

  @enforce_keys [:value, :url]
  defstruct [:value, :url]

  @type t :: %__MODULE__{value: String.t(), url: String.t()}
end
