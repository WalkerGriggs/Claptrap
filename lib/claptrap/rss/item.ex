defmodule Claptrap.RSS.Item do
  @moduledoc """
  Represents an RSS 2.0 `<item>` element with a pipeline-friendly builder API.

  Per the spec, all item elements are optional, but at least one of `title` or
  `description` must be present. This constraint is enforced at validation time,
  not in the builder.
  """

  alias Claptrap.RSS.{Category, Enclosure, Guid, Source}

  @type t :: %__MODULE__{
          title: String.t() | nil,
          link: String.t() | nil,
          description: String.t() | nil,
          author: String.t() | nil,
          comments: String.t() | nil,
          enclosure: Enclosure.t() | nil,
          guid: Guid.t() | nil,
          pub_date: DateTime.t() | nil,
          source: Source.t() | nil,
          categories: [Category.t()],
          extensions: %{String.t() => [map()]}
        }

  defstruct [
    :title,
    :link,
    :description,
    :author,
    :comments,
    :enclosure,
    :guid,
    :pub_date,
    :source,
    categories: [],
    extensions: %{}
  ]

  @spec new(keyword()) :: t()
  def new(opts \\ []), do: struct!(__MODULE__, opts)

  @spec put_title(t(), String.t()) :: t()
  def put_title(%__MODULE__{} = item, title), do: %{item | title: title}

  @spec put_link(t(), String.t()) :: t()
  def put_link(%__MODULE__{} = item, link), do: %{item | link: link}

  @spec put_description(t(), String.t()) :: t()
  def put_description(%__MODULE__{} = item, description),
    do: %{item | description: description}

  @spec put_author(t(), String.t()) :: t()
  def put_author(%__MODULE__{} = item, author), do: %{item | author: author}

  @spec put_comments(t(), String.t()) :: t()
  def put_comments(%__MODULE__{} = item, comments_url), do: %{item | comments: comments_url}

  @spec put_pub_date(t(), DateTime.t()) :: t()
  def put_pub_date(%__MODULE__{} = item, %DateTime{} = datetime),
    do: %{item | pub_date: datetime}

  @spec put_enclosure(t(), Enclosure.t()) :: t()
  def put_enclosure(%__MODULE__{} = item, %Enclosure{} = enclosure),
    do: %{item | enclosure: enclosure}

  @spec put_guid(t(), Guid.t()) :: t()
  def put_guid(%__MODULE__{} = item, %Guid{} = guid), do: %{item | guid: guid}

  @spec put_source(t(), Source.t()) :: t()
  def put_source(%__MODULE__{} = item, %Source{} = source), do: %{item | source: source}

  @spec add_category(t(), Category.t()) :: t()
  def add_category(%__MODULE__{} = item, %Category{} = category),
    do: %{item | categories: item.categories ++ [category]}

  @spec add_extension(t(), String.t(), map()) :: t()
  def add_extension(%__MODULE__{} = item, namespace_uri, element) when is_map(element) do
    extensions = Map.update(item.extensions, namespace_uri, [element], &(&1 ++ [element]))
    %{item | extensions: extensions}
  end
end
