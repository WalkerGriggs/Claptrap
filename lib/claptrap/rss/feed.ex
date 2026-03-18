defmodule Claptrap.RSS.Feed do
  @moduledoc false

  @enforce_keys [:title, :link, :description]
  defstruct [
    # Required (RSS spec: "Required channel elements")
    :title,
    :link,
    :description,

    # Optional (RSS spec: "Optional channel elements")
    :language,
    :copyright,
    :managing_editor,
    :web_master,
    :pub_date,
    :last_build_date,
    :generator,
    :docs,
    :ttl,
    :rating,
    :image,
    :text_input,
    :cloud,
    categories: [],
    skip_hours: [],
    skip_days: [],
    items: [],
    namespaces: %{},
    extensions: %{}
  ]

  @type t :: %__MODULE__{
          title: String.t(),
          link: String.t(),
          description: String.t(),
          language: String.t() | nil,
          copyright: String.t() | nil,
          managing_editor: String.t() | nil,
          web_master: String.t() | nil,
          pub_date: DateTime.t() | nil,
          last_build_date: DateTime.t() | nil,
          generator: String.t() | nil,
          docs: String.t() | nil,
          ttl: non_neg_integer() | nil,
          rating: String.t() | nil,
          image: map() | nil,
          text_input: map() | nil,
          cloud: map() | nil,
          categories: [map()],
          skip_hours: [0..23],
          skip_days: [String.t()],
          items: [map()],
          namespaces: %{optional(String.t()) => String.t()},
          extensions: %{optional(String.t()) => [map()]}
        }
end
