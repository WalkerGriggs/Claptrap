defmodule Claptrap.RSS.Image do
  @moduledoc false

  @enforce_keys [:url, :title, :link]
  defstruct [:url, :title, :link, :width, :height, :description]

  @type t :: %__MODULE__{
          url: String.t(),
          title: String.t(),
          link: String.t(),
          width: non_neg_integer() | nil,
          height: non_neg_integer() | nil,
          description: String.t() | nil
        }
end
