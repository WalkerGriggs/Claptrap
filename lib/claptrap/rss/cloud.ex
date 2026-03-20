defmodule Claptrap.RSS.Cloud do
  @moduledoc false

  @enforce_keys [:domain, :port, :path, :register_procedure, :protocol]
  defstruct [:domain, :port, :path, :register_procedure, :protocol]

  @type t :: %__MODULE__{
          domain: String.t(),
          port: non_neg_integer(),
          path: String.t(),
          register_procedure: String.t(),
          protocol: String.t()
        }
end
