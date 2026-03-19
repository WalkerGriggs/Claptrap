defmodule Claptrap.RSS.Enclosure do
  @moduledoc false

  @enforce_keys [:url, :length, :type]
  defstruct [:url, :length, :type]

  @type t :: %__MODULE__{
          url: String.t(),
          length: non_neg_integer(),
          type: String.t()
        }
end
