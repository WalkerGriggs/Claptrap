# Schemas

Ecto schemas defining Claptrap's four domain entities. These map
directly to PostgreSQL tables and define the shape of data flowing
through the system.

## Architecture

```
Source ──has_many──▶ Entry
  │                    │
  │ tags               │ tags
  │                    │
  │         ┌──────────┘
  │         │  (matched via Postgres && array overlap)
  │         ▼
Sink ──has_many──▶ Subscription
                      │
                      │ tags
```

There is no direct foreign key between entries and sinks. The
connection is implicit: entries are routed to sinks when their
tags overlap with a subscription's tags.

## Key concepts

The four entities and their roles:

- **Source** — An input feed (e.g., an RSS URL). Tracks `type`,
  `name`, `config`, `credentials`, `enabled`, `tags`, and a
  `last_consumed_at` polling cursor.
- **Entry** — A piece of content ingested from a source. Status
  is one of `"unread"`, `"in_progress"`, `"read"`, `"archived"`.
  A unique constraint on `[:external_id, :source_id]` prevents
  duplicate ingestion.
- **Sink** — An output destination (e.g., an RSS feed to
  generate). Structurally mirrors Source but without `tags` or a
  polling cursor.
- **Subscription** — Links a sink to a set of tags. This is the
  routing record: entries whose tags overlap are delivered to the
  associated sink.

All schemas share these conventions:

- **UUID primary keys** using `{:id, :binary_id,
  autogenerate: true}` and `@foreign_key_type :binary_id`.
- **Microsecond timestamps** via
  `timestamps(type: :utc_datetime_usec)`.
- **Credential hiding** — Source and Sink both have a
  `credentials` map that is writable via changesets but excluded
  from `Jason.Encoder` so it never appears in API responses.

## Notes

- Tags appear on Source (inherited by entries at ingest time),
  Entry, and Subscription. The Postgres `&&` array overlap
  operator is the mechanism for matching.
- Source and Sink are structurally symmetric (`type`, `name`,
  `config`, `credentials`, `enabled`). Source adds
  `last_consumed_at` and `tags`; Sink does not.
