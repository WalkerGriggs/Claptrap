defmodule Claptrap.RSS.Guid do
  @moduledoc false

  @enforce_keys [:value]
  defstruct [:value, is_perma_link: true]

  @type t :: %__MODULE__{value: String.t(), is_perma_link: boolean()}
end
