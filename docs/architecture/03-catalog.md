# Catalog

The Catalog is the authoritative owner of Claptrap's persisted resource definitions and the boundary through which other subsystems interact with the database.

## Responsibilities

The Catalog is responsible for:

- CRUD operations on sources, sinks, subscriptions, and entries
- validating shared resource structure while delegating adapter-specific validation to consumer or producer adapters
- querying entries with filters, pagination, and search
- managing tag-based subscription rules used for entry routing
- presenting a stable domain interface to the rest of the system

## Owned resources

The Catalog owns four primary resource classes:

- **sources** — configured upstream content origins
- **entries** — normalized content records discovered from sources
- **sinks** — configured delivery targets
- **subscriptions** — tag-based routing rules that determine which sinks receive entries

These resources should be documented separately because they have different lifecycle semantics even though they share a common persistence boundary.

Detailed resource documents:

- `../catalog/entries.md`
- `../catalog/sources.md`
- `../catalog/sinks.md`
- `../catalog/subscriptions.md`

## Process model

The Catalog is modeled as a single GenServer, `Catalog.Server`, backed by Ecto queries.

Other subsystems call Catalog functions directly through a domain-facing API rather than issuing raw Ecto queries throughout the codebase.

Examples:

- `Catalog.list_sources(filters)` — used by `Consumer.Coordinator` to bootstrap or refresh workers
- `Catalog.create_entry(attrs)` — used by `Consumer.Workers` after normalizing source content
- `Catalog.subscriptions_for_tags(tags)` — used by `Producer.Router` to determine which sinks should receive an entry based on its resolved tag set
- `Catalog.get_sink!(sink_id)` — used by `Producer.Workers` to load sink configuration

## Why a GenServer instead of raw Ecto calls everywhere

The Catalog is more than a convenience wrapper around repository access.

It may:

- cache frequently accessed data such as source configurations or subscription mappings in process state or ETS
- serve as a coordination point for resource-change events
- provide a stable process-local interface to domain operations
- centralize domain invariants that should not be duplicated across callers

One concrete example of the coordination role is broadcasting resource changes such as: a new source was added, so `Consumer.Coordinator` should start a worker.

## Architectural role

The Catalog is the system's central control plane for metadata and persisted content.

- Consumers depend on it to discover source definitions and persist normalized entries.
- Producers depend on it to resolve subscriptions and load sink configuration.
- API and MCP depend on it as the underlying domain interface for persisted resources.

It is therefore both:

- the authoritative persistence boundary, and
- the canonical resource registry for the rest of the application.

## Boundary semantics

The Catalog owns durable metadata and domain resources. It should not absorb responsibilities that belong elsewhere.

In particular:

- consumption protocol logic belongs in consumer adapters
- delivery protocol logic belongs in producer adapters
- runtime retry execution belongs in worker or job orchestration layers
- the Catalog remains the source of truth for resource definitions and persisted normalized content

This boundary is important because it prevents the persistence layer from becoming tightly coupled to every integration-specific behavior.

## Resource interactions

The four Catalog-owned resource classes relate to one another as follows:

- a **source** defines where content comes from
- an **entry** records normalized content discovered from a source
- a **sink** defines where processed content can be delivered
- a **subscription** declares which sinks should receive entries matching a given set of tags

That gives Claptrap a clean control-plane model:

```text
Source -> Entry (with resolved tags) -> Subscription tag match -> Sink
```

The Catalog does not perform the content fetch or delivery itself. It defines the persisted state that allows the consumer and producer subsystems to do that work reliably.

## Why entries stay unified

Although entries have multiple content types such as article, video, podcast, book, and paper, they remain a single Catalog resource.

That is the correct v1 tradeoff because entries share:

- one persistence table
- one common query surface
- one provenance and deduplication model
- one normalized cross-type metadata envelope

Type-specific fields are carried in a typed payload rather than split into separate top-level resources.

## Design consequences

This architecture gives Claptrap a few useful properties:

- callers interact with a single domain boundary rather than scattered persistence code
- resources can evolve independently without collapsing the distinction between consumption, persistence, and delivery
- routing policy remains inspectable because subscriptions are explicit resources
- normalized content remains queryable across types because entries share one envelope

## Future evolution

The Catalog may grow into a richer coordination component over time, for example by:

- maintaining caches for hot resource lookups
- emitting change notifications for worker orchestration
- exposing more sophisticated query capabilities for API and MCP consumers
- supporting richer subscription policies and operational metadata

Those changes should preserve the core boundary: Catalog owns durable domain resources and their invariants; adapters and workers own protocol execution.
