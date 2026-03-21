# Catalog

The data-access context for Claptrap's four domain entities:
sources, sinks, subscriptions, and entries. This is the single
gateway between business logic and the database — all other
modules (API handlers, consumer workers, producer workers) call
through `Claptrap.Catalog` rather than using Ecto/Repo directly.

## Architecture

```
API Handlers ─┐
              │
Consumer ─────┼──▶ Claptrap.Catalog ──▶ Ecto/Repo ──▶ Postgres
              │
Producer ─────┘
```

## Supervisor tree

Not yet wired into the application. The planned tree is
scaffolding for a future in-memory cache or coordination layer:

```
Catalog.Supervisor (:one_for_one)
  │
  └── Catalog.Server (GenServer)
```

`Catalog.Server` currently returns hardcoded empty data and has
no database interaction.

## Key concepts

Tag-based routing via Postgres array overlap is the core domain
mechanism:

- **`subscriptions_for_tags/1`** uses the Postgres `&&` operator
  to find subscriptions whose tags share at least one value with
  the given list.
- **`entries_for_sink/2`** joins entries to subscriptions via tag
  overlap, filters by sink ID, deduplicates, and orders by
  `inserted_at` descending with a configurable limit (default 50).
  Uses a two-step subquery to avoid ordering/limiting conflicts
  with `DISTINCT`.
- **`create_entry/1`** uses `on_conflict: :nothing` with
  `conflict_target: [:external_id, :source_id]`, so re-ingesting
  the same entry from the same source is a silent no-op.

List functions accept keyword options and compose query clauses
conditionally via private `maybe_*` helpers that pattern-match
on `nil`:

```elixir
Catalog.list_entries(status: "unread", source_id: id, limit: 10)
```

## Notes

- Postgres array overlap (`&&`) via `fragment/2` is required for
  tag-based queries — this is a hard dependency on PostgreSQL.
- All four entities have full CRUD functions. Sources and sinks
  support optional `:enabled` filtering on list operations.
