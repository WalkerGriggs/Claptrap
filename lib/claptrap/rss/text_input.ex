defmodule Claptrap.RSS.TextInput do
  @moduledoc false

  @enforce_keys [:title, :description, :name, :link]
  defstruct [:title, :description, :name, :link]

  @type t :: %__MODULE__{
          title: String.t(),
          description: String.t(),
          name: String.t(),
          link: String.t()
        }
end
