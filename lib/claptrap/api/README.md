# API

A Plug-based JSON REST API that exposes Claptrap's catalog
resources over HTTP. All business logic is delegated to
`Claptrap.Catalog` — handlers never touch Ecto or the Repo
directly.

## Architecture

```
HTTP Request
  │
  ▼
Plug pipeline               ← logger, JSON parser,
  │                            content-type, error rescue
  ▼
Router                       ← /health, /ready, forwards to handlers
  │
  ├─ /api/v1/sources/*       → Handlers.Sources
  ├─ /api/v1/sinks/*         → Handlers.Sinks
  ├─ /api/v1/subscriptions/* → Handlers.Subscriptions
  └─ /api/v1/entries/*       → Handlers.Entries
```

## Subdirectories

- **`handlers/`** — One `Plug.Router` module per resource,
  each following the same pattern: delegate to `Catalog`,
  respond with `json/3`, use bang-variant fetches for 404s.

## Key concepts

Not every resource exposes full CRUD:

| Resource      | List | Create | Get | Update | Delete |
|---------------|------|--------|-----|--------|--------|
| Sources       | ✓    | ✓      | ✓   | ✓      | ✓      |
| Sinks         | ✓    | ✓      | ✓   | ✓      | ✓      |
| Subscriptions | ✓    | ✓      | ✓   |        | ✓      |
| Entries       | ✓    |        | ✓   | ✓      |        |

Entries are created by the consumer pipeline, not the API.
Subscriptions are immutable once created — delete and recreate
to change.

Handlers use bang-variant fetches (`get_source!/1`, etc.) that
raise `Ecto.NoResultsError` on missing records. The top-level
plug rescues these globally:

- `Ecto.NoResultsError` → 404
- `Ecto.Query.CastError` → 400
- Anything else → 500

## Notes

- There is no authentication or authorization.
- All responses are `application/json`.
- Filtering is handler-specific: sources/sinks support
  `?enabled=`, subscriptions support `?sink_id=`, and entries
  support `?status=`, `?source_id=`, and `?limit=`.
