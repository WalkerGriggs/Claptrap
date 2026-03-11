# Entries

This document defines the Catalog-owned v1 entity model for entries.

## Purpose

Entries are Claptrap's normalized representation of content discovered from external systems. They are the durable content records persisted by the Catalog and consumed by downstream subsystems such as search, routing, and delivery.

An entry answers two questions:

- what content object does Claptrap believe this is?
- what stable metadata do other subsystems need in order to index, route, display, and process it?

In v1, entries are intentionally modeled as a **single resource** with:

- a shared top-level envelope for cross-type indexing and querying, and
- a type-specific embedded payload for fields that only apply to a particular kind of content.

This keeps the persistence and query model simple while still allowing type-specific structure.

## Resource shape

Every entry has:

- a stable Claptrap ID
- a `type` describing what the content is
- provenance fields that identify where it came from
- common metadata fields used across all content types
- lifecycle timestamps describing both row creation and content publication
- an optional typed payload nested under `data`

Conceptually:

```text
Entry
├── common fields
├── provenance and identity
├── lifecycle timestamps
└── data
    └── exactly one typed payload matching entry.type
```

## Entry types (v1)

In v1, `entries.type` is constrained to:

- `:article`
- `:video`
- `:podcast`
- `:book`
- `:paper`

`type` describes **what the thing is**, not **how it arrived**.

Examples:

- a podcast episode discovered through RSS is still `:podcast`
- a YouTube-hosted recording of a podcast conversation is still `:video`
- a research paper imported from Zotero is still `:paper`

This distinction matters because source protocol and content type are separate concerns. Sources describe consumption boundaries; entry type describes normalized content semantics.

## Type resolution

Type is determined **per entry by the consumer adapter**, not per source.

A single source may emit multiple entry types. For example, an RSS feed may produce both articles and podcast episodes depending on the presence of audio enclosures.

Adapters inspect content signals from the source protocol and choose the normalized type.

### Protocol-specific resolution rules

- **RSS/Atom**: presence of an `<enclosure>` with audio MIME type -> `:podcast`; otherwise -> `:article`
- **YouTube**: always `:video`
- **Zotero**: item type mapping such as `journalArticle` and `conferencePaper` -> `:paper`, `book` -> `:book`
- **Webhook**: type determined by payload structure or explicit sender-provided type field
- **Goodreads**: always `:book`

### Ambiguous cases

When a content object could plausibly fit multiple human interpretations, the adapter should use the **source protocol's native representation** as the tiebreaker.

Example:

- a YouTube upload of a podcast interview is represented natively by YouTube as a video object, so Claptrap stores it as `:video`

This rule keeps type selection deterministic and prevents adapters from drifting into subjective classification.

### Defaulting behavior

Adapters must always set a type.

If an adapter cannot confidently determine a more specific type, it should default to `:article`, which is the broadest and least specialized v1 type.

## Common entry fields

The top-level entry envelope contains fields intended to be broadly useful across all entry types.

### Identity and provenance

- `id`: Claptrap-generated primary key
- `type`: normalized entry type enum
- `source_id`: Claptrap ID of the configured source that emitted the entry
- `external_id`: upstream identifier within that source's namespace

### Cross-type metadata

- `title`: primary display title
- `summary`: short normalized summary or abstract
- `url`: canonical destination URL for the item when available
- `author`: primary author or creator string when a single collapsed representation is useful
- `language`: normalized language tag if known
- `image_url`: primary representative image if available
- `tags`: normalized tag list suitable for indexing and filtering

These are intentionally denormalized for convenience. They allow cross-type querying and indexing without requiring downstream callers to understand the details of every typed payload.

## Timestamp semantics

Entries carry two classes of time information:

- **row lifecycle** timestamps maintained by Claptrap
- **content lifecycle** timestamps derived from upstream metadata or consume behavior

### Row lifecycle timestamps

- `created_at`: when Claptrap first inserted the row; normally immutable
- `updated_at`: when Claptrap last modified the row; maintained by Ecto

### Content lifecycle timestamps

- `ingested_at`: when Claptrap observed or received the item from a source via poll, webhook, or import
- `published_at`: when the upstream content claims it was published

`created_at` and `updated_at` describe the persistence lifecycle of the row.
`ingested_at` and `published_at` describe the lifecycle of the content itself.

### Normal expectations

In ordinary consume flows:

- `created_at ~= ingested_at`
- `published_at` may be earlier than `ingested_at`

In backfills and imports:

- `created_at` reflects when Claptrap inserted the row during the backfill
- `ingested_at` may be set to the reconstructed observation time if that distinction matters operationally

### Fallback and validation rules

- if `published_at` is missing, fall back to `ingested_at`
- if upstream `published_at` is in the future, clamp it to `DateTime.utc_now()` at consume time
- changesets should enforce `published_at <= DateTime.utc_now()`

The goal is simple operational behavior: entries should never appear to have been published in the future.

## Provenance, identity, and deduplication

### `source_id`

`source_id` is Claptrap's internal identifier for a configured source.

A source is a concrete configured upstream integration instance such as:

- a specific RSS feed
- a specific YouTube channel
- a specific Zotero library
- a specific webhook endpoint

Even if two sources use the same protocol, they remain distinct resources with distinct `source_id` values because their configuration, scheduling, and lifecycle are independent.

### `external_id`

`external_id` is the upstream system's identifier for the item **within the namespace of that source**.

Examples:

- RSS: entry GUID or a stable adapter-derived fallback
- YouTube: `videoId`
- podcast via RSS: episode GUID or a stable enclosure-derived identifier
- paper: DOI or arXiv ID
- book: ISBN

`external_id` is treated as immutable for the purposes of idempotency.

If an upstream system rotates or changes identifiers, Claptrap treats the new identifier as a new item. That is the safe default because reliable rename detection across external systems is generally not available.

### Dedupe invariant

The v1 deduplication key is:

- `(source_id, external_id)`

Semantics:

- same `source_id` and same `external_id` -> same upstream item -> duplicate insert should be ignored safely
- different `source_id` and same `external_id` -> not necessarily the same item -> both records must be allowed

This gives Claptrap straightforward idempotency for:

- source re-polls
- webhook retries
- repeated imports

A unique index on `(source_id, external_id)` supports `INSERT ... ON CONFLICT DO NOTHING` style behavior.

## Typed payload model

Entries may include an embedded `data` payload containing fields specific to the selected entry type.

The invariants are:

- `data` may be absent for minimally represented entries
- if `data` is present, it must contain **exactly one** typed payload
- the present payload must match `entries.type`

This lets Claptrap keep a single top-level entries table while still validating type-specific structure.

## Typed payloads

### Article

`article` is the default type for general web writing and similar text-first items.

Expected use cases:

- blog posts
- essays
- documentation pages
- newsletters represented as article-like documents
- RSS items without audio enclosures and without stronger type signals

Fields:

- `site_name`: publication or site name
- `byline`: article-specific author line if different from normalized `author`
- `word_count`: approximate word count if known
- `canonical_url`: canonical URL if different from the top-level `url`

### Video

`video` represents video-native media objects.

Expected use cases:

- YouTube videos
- Vimeo videos
- other platform-native video objects

Fields:

- `platform`: platform identifier such as `"youtube"`
- `video_id`: provider-specific video identifier
- `channel_id`: upstream channel or publisher identifier
- `channel_title`: human-readable channel name
- `duration_seconds`: normalized runtime in seconds

### Podcast

`podcast` represents audio episode objects, usually discovered through RSS or another podcast-native feed format.

Expected use cases:

- podcast episodes with audio enclosures
- audio-first serialized media

Fields:

- `podcast_title`: show title
- `episode_guid`: provider or feed episode GUID
- `episode_number`: episode number when available
- `season_number`: season number when available
- `audio_url`: canonical audio enclosure URL
- `duration_seconds`: normalized runtime in seconds

### Book

`book` represents long-form published books and similar ISBN-oriented content objects.

Expected use cases:

- Goodreads books
- Zotero book items
- other catalog or library records representing books

Fields:

- `isbn10`: ISBN-10 if available
- `isbn13`: ISBN-13 if available
- `publisher`: publisher name
- `published_year`: year of publication

### Paper

`paper` represents scholarly works and research-oriented publications.

Expected use cases:

- journal articles
- conference papers
- preprints
- repository-hosted research artifacts that behave like papers

Fields:

- `doi`: DOI if available
- `arxiv_id`: arXiv identifier if available
- `venue`: conference, journal, or venue name
- `pdf_url`: direct PDF URL when known

## Validation rules

The entry model should enforce the following invariants:

### Required and structural invariants

- `type` is required
- `type` must be one of the v1 enum values
- `data`, when present, must contain exactly one typed payload
- the typed payload present in `data` must match `type`

### Identity invariants

- `(source_id, external_id)` must be unique
- uniqueness must be enforced with a named unique index so the changeset constraint maps cleanly to the database

### Timestamp invariants

- `published_at` must not be in the future after normalization
- `ingested_at` should be set by the consume path, not trusted blindly from upstream input

## Ecto schema shape

The proposed v1 schema uses a stable base set of fields and a type-specific payload nested under `embeds_one :data`.

```elixir
defmodule Claptrap.Schemas.Entry do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @entry_types [:article, :video, :podcast, :book, :paper]

  schema "entries" do
    field :type, Ecto.Enum, values: @entry_types

    belongs_to :source, Claptrap.Schemas.Source
    field :external_id, :string

    field :title, :string
    field :summary, :string
    field :url, :string
    field :author, :string
    field :language, :string
    field :image_url, :string
    field :tags, {:array, :string}

    field :published_at, :utc_datetime_usec
    field :ingested_at, :utc_datetime_usec

    embeds_one :data, Data, on_replace: :update

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [
      :type,
      :source_id,
      :external_id,
      :title,
      :summary,
      :url,
      :author,
      :language,
      :image_url,
      :published_at,
      :ingested_at,
      :tags
    ])
    |> validate_required([:type])
    |> cast_embed(:data, with: &Data.changeset/2, required: false)
    |> Data.validate_matches_type()
    |> unique_constraint([:source_id, :external_id], name: :entries_source_id_external_id_index)
  end

  defmodule Data do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      embeds_one :article, Article
      embeds_one :video, Video
      embeds_one :podcast, Podcast
      embeds_one :book, Book
      embeds_one :paper, Paper
    end

    def changeset(data, attrs) do
      data
      |> cast(attrs, [])
      |> cast_embed(:article, with: &Article.changeset/2)
      |> cast_embed(:video, with: &Video.changeset/2)
      |> cast_embed(:podcast, with: &Podcast.changeset/2)
      |> cast_embed(:book, with: &Book.changeset/2)
      |> cast_embed(:paper, with: &Paper.changeset/2)
    end

    def validate_matches_type(%Ecto.Changeset{} = entry_cs) do
      type = get_field(entry_cs, :type)
      data = get_field(entry_cs, :data)

      if is_nil(data) do
        entry_cs
      else
        present =
          [:article, :video, :podcast, :book, :paper]
          |> Enum.filter(fn k -> not is_nil(Map.get(data, k)) end)

        entry_cs
        |> validate_exactly_one(present)
        |> validate_type_matches_present(type, present)
      end
    end

    defp validate_exactly_one(entry_cs, present) do
      case present do
        [_one] ->
          entry_cs

        [] ->
          add_error(entry_cs, :data, "must include exactly one typed payload (article/video/podcast/book/paper)")

        _many ->
          add_error(
            entry_cs,
            :data,
            "must not include multiple typed payloads (got: #{Enum.join(Enum.map(present, &Atom.to_string/1), ", ")})"
          )
      end
    end

    defp validate_type_matches_present(entry_cs, type, present) do
      case {type, present} do
        {nil, _} ->
          entry_cs

        {t, [t]} ->
          entry_cs

        {t, [_other]} ->
          add_error(entry_cs, :type, "does not match data payload (type=#{t}, payload=#{hd(present)})")

        {_t, _} ->
          entry_cs
      end
    end

    defmodule Article do
      use Ecto.Schema
      import Ecto.Changeset

      @primary_key false
      embedded_schema do
        field :site_name, :string
        field :byline, :string
        field :word_count, :integer
        field :canonical_url, :string
      end

      def changeset(article, attrs) do
        article
        |> cast(attrs, [:site_name, :byline, :word_count, :canonical_url])
      end
    end

    defmodule Video do
      use Ecto.Schema
      import Ecto.Changeset

      @primary_key false
      embedded_schema do
        field :platform, :string
        field :video_id, :string
        field :channel_id, :string
        field :channel_title, :string
        field :duration_seconds, :integer
      end

      def changeset(video, attrs) do
        video
        |> cast(attrs, [:platform, :video_id, :channel_id, :channel_title, :duration_seconds])
      end
    end

    defmodule Podcast do
      use Ecto.Schema
      import Ecto.Changeset

      @primary_key false
      embedded_schema do
        field :podcast_title, :string
        field :episode_guid, :string
        field :episode_number, :integer
        field :season_number, :integer
        field :audio_url, :string
        field :duration_seconds, :integer
      end

      def changeset(podcast, attrs) do
        podcast
        |> cast(attrs, [:podcast_title, :episode_guid, :episode_number, :season_number, :audio_url, :duration_seconds])
      end
    end

    defmodule Book do
      use Ecto.Schema
      import Ecto.Changeset

      @primary_key false
      embedded_schema do
        field :isbn10, :string
        field :isbn13, :string
        field :publisher, :string
        field :published_year, :integer
      end

      def changeset(book, attrs) do
        book
        |> cast(attrs, [:isbn10, :isbn13, :publisher, :published_year])
      end
    end

    defmodule Paper do
      use Ecto.Schema
      import Ecto.Changeset

      @primary_key false
      embedded_schema do
        field :doi, :string
        field :arxiv_id, :string
        field :venue, :string
        field :pdf_url, :string
      end

      def changeset(paper, attrs) do
        paper
        |> cast(attrs, [:doi, :arxiv_id, :venue, :pdf_url])
      end
    end
  end
end
```

## Migration note

The schema references the unique constraint name `:entries_source_id_external_id_index`.

The migration should create the unique index with that exact name, or the schema should be updated to match whatever index name is standardized in the migration layer.

## Relationship to the rest of the Catalog

Entries are only one Catalog-owned resource. The Catalog also owns:

- sources, which define where entries come from
- sinks, which define where processed content can be delivered
- subscriptions, which define source-to-sink routing relationships

Those resources are documented separately so that the entry model can stay focused on normalized content structure rather than broader Catalog responsibilities.
