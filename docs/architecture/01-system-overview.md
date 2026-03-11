# System Overview

Claptrap is structured as a set of Elixir/OTP processes that consume content from external sources, normalize it into a common internal representation, and deliver it to downstream sinks.

For an explanation of OTP primitives such as GenServer and Supervisor, see `file 'Claptrap/docs/elixir.md'`.

## Why Elixir/OTP for Claptrap

Claptrap is fundamentally a system of concurrent, long-running processes that need to:

- **Consume dozens of sources on independent schedules** (RSS feeds every 15 min, YouTube every hour, Zotero once a day) and via **push triggers** (webhooks)
- **Deliver entries to multiple sinks concurrently** (combined RSS feeds, webhooks, email — each with different delivery semantics)
- **Stay alive indefinitely** as a personal daemon, recovering gracefully from failures in any individual component

This is exactly the problem space Erlang/OTP was designed for: systems that must run continuously, handle many concurrent activities, and recover from localized failures without dropping the entire system.

## Why Plug + Bandit

Claptrap still needs an HTTP boundary for:

- REST API endpoints
- webhook receivers for push-based sources
- pull sink endpoints such as RSS feed retrieval
- MCP over HTTP/SSE

The project uses **Plug + Bandit** for that boundary because it keeps the web layer thin and explicit. Claptrap is primarily an OTP application with a small HTTP adapter, not a Phoenix-style web application.

Phoenix is retained only where it adds value independently of the web framework: **Phoenix.PubSub** remains the internal event bus.

## Major Subsystems

Claptrap consists of five subsystems:

| Subsystem | Responsibility |
| --- | --- |
| **Catalog** | Central registry. Connects to PostgreSQL. Manages all resource definitions (sources, sinks, subscriptions). Vends and lists records to surrounding processes. |
| **Consumer** | Source consumption. One worker per source. Consumes sources (pull or push), normalizes content into entries, deduplicates, persists. |
| **Producer** | Feed delivery. One worker per sink. Packages entries into output formats (RSS feeds, webhooks, email) via producer adapters and either pushes them or materializes artifacts for later retrieval. |
| **API** | External HTTP interface implemented with Plug and served by Bandit. Exposes REST endpoints, webhooks, and pull sink URLs. |
| **MCP** | AI agent interface. Model Context Protocol server that bridges agents to the same underlying domain interfaces over HTTP/SSE. |

## Core Data Flow

```markdown
Source → Consumer (via Consumer.Adapter) → Entry → Producer (via Producer.Adapter) → Sink
```

```markdown
External Sources                    External Sinks
(RSS, YouTube, Zotero, etc.)        (RSS feeds, webhooks, email, etc.)
        │                                    ▲
        ▼                                    │
┌───────────────────┐              ┌─────────────────────┐
│     Consumer      │              │      Producer       │
│ Consumer Adapters │              │  Producer Adapters  │
│ normalize → entry │              │ entry → output fmt  │
└────────┬──────────┘              └──────────▲──────────┘
         │                                    │
         ▼                                    │
┌─────────────────────────────────────────────────────────┐
│                      Catalog                            │
│                    (PostgreSQL)                         │
│       sources, entries, subscriptions, sinks            │
└──────────┬────────────────────────────┬─────────────────┘
           │                            │
           ▼                            ▼
   ┌──────────────┐            ┌──────────────┐
   │     API      │            │     MCP      │
   │  REST/HTTP   │            │  JSON-RPC    │
   └──────────────┘            └──────────────┘
```

**Sources** are the external or upstream data providers. **Consumers** consume entries from sources using **consumer adapters** to normalize source-native formats into entries. **Producers** publish entries to sinks using **producer adapters** to transform entries into sink-native formats or representations. **Sinks** are the downstream destinations.

Within the cluster, everything is an Entry.

## Roles vs Transport

**Consumer vs Producer is defined by direction across the Claptrap boundary**, not by who initiates network I/O.

- **Consumer**: external → Entry (ingress)
- **Producer**: Entry → external (egress)

**Push vs pull** is a boundary transport detail:

- Pull sources are scheduled or polled by Claptrap.
- Push sources call Claptrap (webhooks); the API layer enqueues consumption work into the appropriate Consumer worker.
- Push sinks are actively delivered to by Claptrap (webhook, Slack, email).
- Pull sinks are materialized by Claptrap and served via an HTTP endpoint (for example, RSS feed retrieval).

## Related Documents

- `file 'Claptrap/docs/architecture/02-supervision-tree.md'`
- `file 'Claptrap/docs/architecture/03-catalog.md'`
- `file 'Claptrap/docs/architecture/04-consumer.md'`
- `file 'Claptrap/docs/architecture/05-producer.md'`
- `file 'Claptrap/docs/architecture/06-api-and-mcp.md'`
- `file 'Claptrap/docs/architecture/07-pubsub-and-data-flow.md'`
