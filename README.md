# Claptrap

A personal information diet manager. Claptrap monitors, maintains, and accumulates content from your favorite sources—RSS feeds, content streams, integrations like Zotero—and consolidates them into a system of record.

- **Monitor** new content from your favorite RSS feeds and YouTube subscriptions
- **Integrate** with knowledge management tools like Zotero.
- **Organize** entries by status (unread, in progress, read, archived) in a unified dashboard
- **Deliver** curated content through various output channels

## Architecture

Claptrap follows a source → consumer → database → producer → sink pattern:

```markdown
Sources (RSS, YouTube, APIs) → Consumers → [PostgreSQL] → Producers → Sinks (Slack, Webhooks, etc.)
                                        ↑
                                   MCP Server
                                   Dashboard
                                   Chatbot/Agent
```

### Core Components

- **Sources**: Anything that emits new elements (RSS feeds, webhooks, APIs)
- **Consumers**: Pull data from sources
- **Database**: PostgreSQL for CRUD operations on all records
- **Producers**: Push elements to sinks
- **Sinks**: Aggregation points (webhooks, Slack, APIs)

### Subsystems

Claptrap is built from five subsystems:

1. **Catalog**: Central registry for sources, sinks, subscriptions, and entries (PostgreSQL-backed)
2. **Consumer**: Source ingestion engine — one worker per source
3. **Producer**: Feed delivery engine — one worker per sink
4. **API**: REST endpoints for external access
5. **MCP**: Model Context Protocol server for AI agent integration

## Documentation

- [Glossary](docs/glossary.md) - Core terminology and concepts
- [Integrations](docs/integrations.md) - Supported source and sink adapters
- [Architecture](docs/architecture.md) - Detailed Elixir/OTP system design
- [Entities](docs/entities.md) - Data model and entry types

## ADRs

Architectural Decision Records are stored in the adr/ directory. See adr/template.md for the template format.

## Technical Stack

**Language**: Elixir (on the BEAM VM)

- Erlang/OTP provides battle-tested primitives for concurrent, fault-tolerant systems
- Supervision trees handle process lifecycle and crash recovery automatically
- Per-process isolation eliminates shared-memory bugs (no mutexes, no data races)
- Phoenix framework for HTTP API, WebSocket, and LiveView dashboard

**Architecture**: OTP supervision tree with clear subsystem boundaries

- **Catalog**: PostgreSQL-backed registry for all resources (sources, sinks, subscriptions, entries)
- **Consumer**: One GenServer worker per source — handles polling, normalization, and persistence
- **Producer**: One GenServer worker per sink — handles formatting, delivery, and retry
- **PubSub**: Phoenix.PubSub for internal event routing (no external message broker needed)
- **API**: Phoenix HTTP endpoints for REST operations
- **MCP**: Model Context Protocol server for AI agent integration

**Deployment**:

- v1: Single Elixir release (self-contained binary with BEAM VM and PostgreSQL)
- Future: Distributed Erlang clustering support (designed to avoid one-way doors)