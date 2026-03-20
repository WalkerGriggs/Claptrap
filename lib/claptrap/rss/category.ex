defmodule Claptrap.RSS.Category do
  @moduledoc false

  @enforce_keys [:value]
  defstruct [:value, :domain]

  @type t :: %__MODULE__{value: String.t(), domain: String.t() | nil}
end
