# Project Structure

This document maps the proposed source tree to the runtime architecture.

## Proposed Layout

```markdown
claptrap/
├── lib/
│   ├── claptrap/
│   │   ├── application.ex            # OTP Application — supervision tree root
│   │   ├── repo.ex                   # Ecto Repo — database connection pool
│   │   │
│   │   ├── catalog/
│   │   │   ├── supervisor.ex         # Supervises Catalog.Server
│   │   │   └── server.ex             # GenServer — central registry
│   │   │
│   │   ├── consumer/
│   │   │   ├── supervisor.ex         # Supervises coordinator + worker supervisor
│   │   │   ├── coordinator.ex        # Bootstrap + periodic poll coordination
│   │   │   ├── worker.ex             # GenServer per source
│   │   │   └── adapter.ex            # Behaviour definition for consumer adapters
│   │   │
│   │   ├── consumer/adapters/        # Consumer adapter implementations
│   │   │   ├── rss.ex
│   │   │   ├── youtube.ex
│   │   │   ├── zotero.ex
│   │   │   └── webhook.ex
│   │   │
│   │   ├── producer/
│   │   │   ├── supervisor.ex         # Supervises router + worker supervisor
│   │   │   ├── router.ex             # PubSub subscriber, routes to sinks
│   │   │   ├── worker.ex             # GenServer per sink
│   │   │   └── adapter.ex            # Behaviour definition for producer adapters
│   │   │
│   │   ├── producer/adapters/        # Producer adapter implementations
│   │   │   ├── rss_feed.ex
│   │   │   ├── webhook.ex
│   │   │   ├── email.ex
│   │   │   └── slack.ex
│   │   │
│   │   ├── api/
│   │   │   ├── plug.ex               # Top-level Plug pipeline
│   │   │   ├── router.ex             # Route definitions
│   │   │   ├── auth.ex               # API key auth plug
│   │   │   └── handlers/             # Request handlers by resource
│   │   │       ├── entries.ex
│   │   │       ├── sources.ex
│   │   │       ├── sinks.ex
│   │   │       ├── subscriptions.ex
│   │   │       └── webhooks.ex
│   │   │
│   │   ├── mcp/
│   │   │   └── server.ex             # MCP protocol handler
│   │   │
│   │   ├── schemas/                  # Ecto schemas + changesets
│   │   │   ├── source.ex
│   │   │   ├── entry.ex
│   │   │   ├── subscription.ex
│   │   │   └── sink.ex
│   │   │
│   │   └── telemetry.ex              # Telemetry event handlers
│   │
│   └── claptrap/api_server.ex        # Bandit child spec / HTTP startup
│
├── priv/
│   └── repo/
│       └── migrations/
│
├── config/
│   ├── config.exs                    # Compile-time shared config
│   ├── dev.exs
│   ├── test.exs
│   ├── prod.exs
│   └── runtime.exs                   # Runtime config (env vars)
│
├── test/                             # Tests mirror lib/ structure
│
├── mix.exs                           # Project definition + dependencies
└── mix.lock                          # Locked dependency versions
```

## Mapping Structure to Runtime Architecture

The project layout tracks the runtime subsystem boundaries closely:

- `application.ex` defines the supervision tree root
- `catalog/` maps to the central registry and persistence boundary
- `consumer/` maps to source consumption concerns
- `producer/` maps to sink delivery concerns
- `api/` and `mcp/` expose external interfaces
- `schemas/` hold Ecto persistence types and validation boundaries
- `telemetry.ex` centralizes observability hooks

This is a good code organization choice because it mirrors the operational model rather than organizing only by transport layer or framework concern.

## Key Dependencies

| Dependency | Purpose |
| --- | --- |
| `plug` | HTTP abstraction and request pipeline |
| `bandit` | HTTP server |
| `ecto_sql` + `postgrex` | PostgreSQL access, connection pooling, and migrations |
| `phoenix_pubsub` | Internal event bus |
| `req` | HTTP client for adapter fetches |
| `floki` | HTML parsing for content extraction |
| `jason` | JSON encoding and decoding |
| `cloak_ecto` | Credential encryption at rest |

## Design Intent

The proposed file layout is not arbitrary. It is explicitly aligned with:

- supervision boundaries
- subsystem ownership
- behaviour-based adapter extensibility
- clear separation between domain logic and the thin HTTP adapter layer
