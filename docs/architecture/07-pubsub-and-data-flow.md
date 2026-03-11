# PubSub and Data Flow

This document covers how data moves through Claptrap and how internal processes communicate.

## End-to-End Data Flow

```markdown
Source → Consumer (via Consumer.Adapter) → Entry → Producer (via Producer.Adapter) → Sink
```

Claptrap's architectural center of gravity is the `Entry`.

- Sources are external upstream systems.
- Consumers normalize source-native representations into entries.
- Producers transform entries into sink-native representations.
- Sinks are downstream destinations.

Within the cluster, everything is an Entry.

## Boundary Semantics: Push vs Pull

Consumer versus Producer is defined by direction across the Claptrap boundary, not by who initiates the network call.

- **Consumer**: external → Entry
- **Producer**: Entry → external

Push and pull are transport details layered on top of that model.

### Source side

- Pull sources are scheduled and polled by Claptrap.
- Push sources call Claptrap, usually through webhooks, and the HTTP layer enqueues work into the correct Consumer worker.

### Sink side

- Push sinks are actively delivered to by Claptrap.
- Pull sinks are materialized by Claptrap and then served via HTTP when requested.

## Internal Event Bus

Claptrap uses **Phoenix.PubSub** as the internal event bus. This is an independent library from the Phoenix ecosystem, not a commitment to Phoenix as the web framework.

It replaces the need for an external message queue such as NATS or RabbitMQ for the initial architecture.

## Key Topics

| Topic | Publishers | Subscribers | Event Shape |
| --- | --- | --- | --- |
| `entries:new` | Consumer.Workers (via Catalog) | Producer.Router | `{:entries_ingested, source_id, entries}` |
| `catalog:changed` | Catalog.Server | Consumer.Coordinator, Producer.Router | `{:resource_changed, type, action, id}` |

## Why Phoenix.PubSub

The rationale is pragmatic:

- **No external dependency**: PubSub is a library, not a daemon to operate
- **No serialization overhead**: messages are native Elixir terms
- **Topic-based fanout**: multiple subscribers can react to the same fact without point-to-point wiring
- **Distributed by default**: messages can flow across Erlang nodes if the system later becomes clustered
- **Lower latency**: in-process message passing is extremely cheap

## Contract Boundary

PubSub is also the subsystem contract boundary.

- Consumers do not know about sinks.
- Producers do not need to know how consumption was performed.
- The Router depends only on the event shape, not on consumer implementation details.

This keeps subsystem boundaries explicit while avoiding heavier distributed systems machinery too early.