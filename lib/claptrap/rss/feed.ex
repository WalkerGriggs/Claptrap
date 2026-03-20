defmodule Claptrap.RSS.Feed do
  @moduledoc """
  Represents an RSS 2.0 `<channel>` element with a pipeline-friendly builder API.

  Builder functions follow Elixir convention: `put_*` replaces a field value,
  `add_*` appends to a list. Every function returns the updated struct for use
  with `|>` pipelines. No validation is performed in builders — that happens at
  generate-time.
  """

  alias Claptrap.RSS.{Category, Cloud, Image, Item, TextInput}

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
          cloud: Cloud.t() | nil,
          image: Image.t() | nil,
          text_input: TextInput.t() | nil,
          categories: [Category.t()],
          skip_hours: [0..23],
          skip_days: [String.t()],
          items: [Item.t()],
          namespaces: %{String.t() => String.t()},
          extensions: %{String.t() => [map()]}
        }

  @enforce_keys [:title, :link, :description]
  defstruct [
    :title,
    :link,
    :description,
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
    :cloud,
    :image,
    :text_input,
    categories: [],
    skip_hours: [],
    skip_days: [],
    items: [],
    namespaces: %{},
    extensions: %{}
  ]

  @valid_days ~w(Monday Tuesday Wednesday Thursday Friday Saturday Sunday)

  @spec new(String.t(), String.t(), String.t()) :: t()
  def new(title, link, description) do
    %__MODULE__{title: title, link: link, description: description}
  end

  @spec put_language(t(), String.t()) :: t()
  def put_language(%__MODULE__{} = feed, language), do: %{feed | language: language}

  @spec put_copyright(t(), String.t()) :: t()
  def put_copyright(%__MODULE__{} = feed, copyright), do: %{feed | copyright: copyright}

  @spec put_managing_editor(t(), String.t()) :: t()
  def put_managing_editor(%__MODULE__{} = feed, email), do: %{feed | managing_editor: email}

  @spec put_web_master(t(), String.t()) :: t()
  def put_web_master(%__MODULE__{} = feed, email), do: %{feed | web_master: email}

  @spec put_pub_date(t(), DateTime.t()) :: t()
  def put_pub_date(%__MODULE__{} = feed, %DateTime{} = datetime),
    do: %{feed | pub_date: datetime}

  @spec put_last_build_date(t(), DateTime.t()) :: t()
  def put_last_build_date(%__MODULE__{} = feed, %DateTime{} = datetime),
    do: %{feed | last_build_date: datetime}

  @spec put_generator(t(), String.t()) :: t()
  def put_generator(%__MODULE__{} = feed, generator), do: %{feed | generator: generator}

  @spec put_docs(t(), String.t()) :: t()
  def put_docs(%__MODULE__{} = feed, docs_url), do: %{feed | docs: docs_url}

  @spec put_ttl(t(), non_neg_integer()) :: t()
  def put_ttl(%__MODULE__{} = feed, ttl) when is_integer(ttl) and ttl >= 0,
    do: %{feed | ttl: ttl}

  @spec put_image(t(), Image.t()) :: t()
  def put_image(%__MODULE__{} = feed, %Image{} = image), do: %{feed | image: image}

  @spec put_text_input(t(), TextInput.t()) :: t()
  def put_text_input(%__MODULE__{} = feed, %TextInput{} = text_input),
    do: %{feed | text_input: text_input}

  @spec put_cloud(t(), Cloud.t()) :: t()
  def put_cloud(%__MODULE__{} = feed, %Cloud{} = cloud), do: %{feed | cloud: cloud}

  @spec add_item(t(), Item.t()) :: t()
  def add_item(%__MODULE__{} = feed, %Item{} = item),
    do: %{feed | items: feed.items ++ [item]}

  @spec add_category(t(), Category.t()) :: t()
  def add_category(%__MODULE__{} = feed, %Category{} = category),
    do: %{feed | categories: feed.categories ++ [category]}

  @spec add_skip_hour(t(), 0..23) :: t()
  def add_skip_hour(%__MODULE__{} = feed, hour) when hour in 0..23,
    do: %{feed | skip_hours: feed.skip_hours ++ [hour]}

  @spec add_skip_day(t(), String.t()) :: t()
  def add_skip_day(%__MODULE__{} = feed, day) when day in @valid_days,
    do: %{feed | skip_days: feed.skip_days ++ [day]}

  @spec put_namespace(t(), String.t(), String.t()) :: t()
  def put_namespace(%__MODULE__{} = feed, prefix, uri),
    do: %{feed | namespaces: Map.put(feed.namespaces, prefix, uri)}

  @spec add_extension(t(), String.t(), map()) :: t()
  def add_extension(%__MODULE__{} = feed, namespace_uri, element) when is_map(element) do
    extensions = Map.update(feed.extensions, namespace_uri, [element], &(&1 ++ [element]))
    %{feed | extensions: extensions}
  end
end
