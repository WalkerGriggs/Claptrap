defmodule Claptrap.RSS.Item do
  @moduledoc false

  @type t :: %__MODULE__{
          title: String.t() | nil,
          link: String.t() | nil,
          description: String.t() | nil,
          author: String.t() | nil,
          comments: String.t() | nil,
          pub_date: DateTime.t() | nil,
          enclosure: enclosure() | nil,
          guid: guid() | nil,
          source: source() | nil,
          categories: [category()],
          extensions: %{optional(String.t()) => [%{name: String.t(), attrs: map(), value: term()}]}
        }

  @typep enclosure :: map()
  @typep guid :: map()
  @typep source :: map()
  @typep category :: map()

  defstruct [
    :title,
    :link,
    :description,
    :author,
    :comments,
    :pub_date,
    :enclosure,
    :guid,
    :source,
    categories: [],
    extensions: %{}
  ]
end
