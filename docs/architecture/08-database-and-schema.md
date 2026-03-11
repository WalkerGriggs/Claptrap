# Database and Schema

Claptrap uses PostgreSQL with Ecto for persistence.

## Core Tables

### entries

The atomic unit of content within the cluster.

- `id` (UUID)
- `source_id` (UUID, references sources)
- `external_id` (VARCHAR) — identifier from the source system
- `title`, `summary`, `url`, `author`, `published_at`
- `status` (ENUM) — `unread`, `in_progress`, `read`, `archived`
- `metadata` (JSONB) — flexible attributes
- `tags` (TEXT[]) — user-defined tags
- UNIQUE constraint on `(external_id, source_id)` for deduplication

### sources

External or upstream data providers.

- `id` (UUID)
- `type` (VARCHAR) — `rss`, `youtube`, `zotero`, and similar
- `name` (VARCHAR) — user-friendly name
- `config` (JSONB) — source-specific configuration such as URL or filters
- `credentials` (JSONB) — encrypted credentials such as API keys or OAuth tokens
- `enabled` (BOOLEAN)
- `last_consumed_at` (TIMESTAMPTZ) — last successful consume, whether by poll or webhook consumption
- `tags` (TEXT[]) — user-defined tags used for subscription matching

### subscriptions

Links sinks to source tags using pure tag-based routing.

- `id` (UUID)
- `sink_id` (UUID, references sinks)
- `tags` (TEXT[]) — a sink subscribes to sources with any overlapping tag
- INDEX on `sink_id`
- GIN INDEX on `tags` for efficient overlap queries using the `&&` operator

### sinks

Downstream destinations for entries.

- `id` (UUID)
- `type` (VARCHAR) — `rss_feed`, `webhook`, `email`, and similar
- `name` (VARCHAR)
- `config` (JSONB) — sink-specific configuration such as webhook URL or feed title
- `credentials` (JSONB) — encrypted credentials
- `enabled` (BOOLEAN)

## Why JSONB for Config and Metadata

Each source and sink type has materially different configuration requirements.

- RSS needs a URL
- YouTube needs a channel ID and possibly an API key
- Zotero needs OAuth tokens

JSONB allows the schema to remain stable while adapter-specific configuration evolves. That avoids introducing a separate relational schema for every source and sink type before the system has proven it needs one.

Validation still happens explicitly: adapters validate config shape through `validate_config/1`.

## Deduplication Model

Deduplication is handled at the database layer.

The architecture uses Ecto's `on_conflict: :nothing` with a conflict target of `[:external_id, :source_id]`. This ensures re-running a poll against the same source is safe and idempotent from the insertion perspective.

## Persistence Boundary

The database is not just a storage engine. It anchors several correctness properties:

- entry deduplication
- source and sink configuration persistence
- subscription routing metadata
- restart-safe canonical state for the system's topology

That makes PostgreSQL the primary durable boundary of the system.
