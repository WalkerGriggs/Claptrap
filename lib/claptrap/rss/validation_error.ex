defmodule Claptrap.RSS.ValidationError do
  @moduledoc false

  @enforce_keys [:message, :path, :rule]
  defstruct [:message, :path, :rule]

  @type t :: %__MODULE__{
          message: String.t(),
          path: [atom() | non_neg_integer()],
          rule: atom()
        }
end
