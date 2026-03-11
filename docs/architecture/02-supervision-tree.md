# Supervision Tree

Every box in the supervision tree is a process or supervisor managing processes. The tree is read top-down: parents start before children, and a parent crashing takes its entire subtree down, after which the parent's supervisor restarts that subtree.

## Complete Supervision Tree

```markdown
Claptrap.Application (OTP Application root)
│
├── Claptrap.Repo (Ecto — PostgreSQL connection pool)
│     Pool of database connections. Ecto manages the pool lifecycle.
│     Started first because every other subsystem needs the database.
│
├── Claptrap.Registry (Process name registry)
│     Maps {type, id} tuples to PIDs. Used by all subsystems.
│
├── Claptrap.PubSub (Phoenix.PubSub — internal event bus)
│     In-process pub/sub. Decouples consumers from producers.
│
├── Claptrap.Vault (Cloak.Ecto — credential encryption)
│     Manages encryption keys for source/sink credentials at rest.
│     Started before Consumer/Producer since they need to decrypt configs.
│
├── Catalog.Supervisor ── strategy: :one_for_one
│   │   Central registry for all resource definitions.
│   │   Owns the domain logic for sources, sinks, subscriptions, entries.
│   │
│   └── Catalog.Server (GenServer)
│         Provides a process-local API for querying and managing
│         resources. Other subsystems call Catalog functions to
│         list sources, look up subscriptions, create entries, etc.
│         Backed by Ecto queries against PostgreSQL.
│
├── Consumer.Supervisor ── strategy: :rest_for_one
│   │   Source consumption engine. Consumes sources and normalizes to entries.
│   │   :rest_for_one because the Coordinator depends on WorkerSupervisor
│   │   existing — if the WorkerSupervisor crashes, the Coordinator must
│   │   restart too (its references to workers are now stale).
│   │
│   ├── Consumer.WorkerSupervisor (DynamicSupervisor, :one_for_one)
│   │   │   Each child is independent — one RSS feed crashing doesn't
│   │   │   affect a YouTube consumer.
│   │   │
│   │   ├── Consumer.Worker (RSS: "Hacker News")
│   │   ├── Consumer.Worker (RSS: "lobste.rs")
│   │   ├── Consumer.Worker (YouTube: "@channel")
│   │   ├── Consumer.Worker (Zotero: "My Library")
│   │   └── ... one process per configured source
│   │
│   └── Consumer.Coordinator (GenServer)
│         Periodic timer. On each tick, queries the Catalog for pull sources
│         that are due for a poll and sends :poll messages to their workers.
│         Also responsible for bootstrapping: on init, starts a worker for
│         every enabled source in the database.
│
├── Producer.Supervisor ── strategy: :rest_for_one
│   │   Feed delivery engine. Routes entries to sinks.
│   │   Same rationale for :rest_for_one as Consumer.
│   │
│   ├── Producer.WorkerSupervisor (DynamicSupervisor, :one_for_one)
│   │   │
│   │   ├── Producer.Worker (RSS Feed: "combined")
│   │   ├── Producer.Worker (Webhook: "https://...")
│   │   ├── Producer.Worker (Email: daily digest)
│   │   └── ... one process per configured sink
│   │
│   └── Producer.Router (GenServer)
│         Subscribes to PubSub topic "entries:new". When new entries arrive,
│         looks up which sinks care about them (via subscription rules in
│         the Catalog) and sends {:deliver, entries} to the appropriate
│         Producer.Workers.
│
└── API.Supervisor ── strategy: :one_for_one
    │   External interfaces. Independent children — the HTTP server
    │   crashing doesn't need to take down the MCP server or vice versa.
    │
    ├── Claptrap.API.Server (Bandit — HTTP server)
    │     Serves the Plug-based HTTP interface.
    │     REST API for CRUD operations.
    │     Webhook receiver endpoints (push-based sources).
    │     Pull sink endpoints (e.g., RSS feed retrieval).
    │     MCP HTTP/SSE transport endpoint.
    │
    └── Claptrap.MCP.Server (GenServer — MCP protocol handler)
          Model Context Protocol server for AI agent integration.
          Speaks MCP over HTTP/SSE via the Plug interface.
          Routes requests to the same Catalog and domain functions
          that the REST API uses.
```

## Why This Tree Has This Shape

The supervision tree encodes failure domain design.

### Shared infrastructure as direct children

**Repo, Registry, PubSub, and Vault are direct children of the Application supervisor.** If any crash, the Application supervisor restarts them. Every subsystem depends on these. If the database pool dies, nothing works. By making them direct children rather than nesting them under Consumer or Producer, a shared dependency failure does not unnecessarily cascade through unrelated worker hierarchies.

### Consumer and Producer use `:rest_for_one`

The Coordinator or Router depends on its WorkerSupervisor existing. If the WorkerSupervisor crashes and all workers disappear, those higher-level processes may hold stale references. `:rest_for_one` ensures the dependent process is restarted after the WorkerSupervisor is restarted.

### WorkerSupervisors use `:one_for_one`

Each worker is independent. One RSS feed crashing should not affect a YouTube worker. One webhook sink failure should not restart an email sink worker.

### API uses `:one_for_one`

The Bandit HTTP server crashing does not imply the MCP server should also be taken down. They are independent entry points to the same underlying Catalog and system services.

## Failure Domain Summary

- Shared infrastructure failure is handled at the application root.
- Per-source and per-sink failures are isolated to individual workers.
- Coordinator and Router are restarted when their worker topology becomes invalid.
- External interfaces are isolated from each other.
