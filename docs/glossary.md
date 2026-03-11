# Glossary

This document defines the core terminology used throughout Claptrap.

## Data Flow

```
Source → Consumer (via Consumer.Adapter) → Entry → Producer (via Producer.Adapter) → Sink
```

## Roles vs Transport (Push vs Pull)

**Consumer vs Producer are directional roles across the Claptrap boundary**, not a statement about who initiates I/O.

- **Consumer** = ingress into Claptrap (external → Entry)
- **Producer** = egress out of Claptrap (Entry → external)

**Push vs Pull** describes the *transport / trigger mode* at the boundary:

- **Pull source**: Claptrap initiates consumption by polling/fetching on a schedule (RSS, YouTube, APIs).
- **Push source**: an external system initiates consumption by calling Claptrap (webhooks).
- **Push sink**: Claptrap initiates delivery to the destination (webhooks, Slack, email).
- **Pull sink**: Claptrap materializes an artifact that downstream clients fetch later (RSS feed served over HTTP).

## Data Entities

### Entry

The atomic unit of content in Claptrap. An entry represents a discrete piece of consumable information such as a blog post, news article, or conference talk. Within the cluster, all content is normalized to entries regardless of its original source format.

Entry type (`:article`, `:video`, `:podcast`, `:book`, `:paper`) is determined per-entry by the consumer adapter based on content signals from the source protocol. See [entities.md](entities.md) for the full type resolution rules.

### Source

An external or upstream provider of content to consume into Claptrap (RSS feeds, YouTube channels, Zotero libraries, webhooks, APIs, etc.).

A source is a configuration record in the Catalog (URL, credentials, and optionally a schedule). Each source has an associated **consumer adapter** that normalizes source-native content into entries.

Sources may be **pull-triggered** (polled on an interval) or **push-triggered** (consumed via webhook calls). This transport detail does not change the role: all sources are consumed by the Consumer subsystem.

### Sink

A downstream destination for entries (combined RSS feeds, webhooks, email digests, Slack channels, etc.).

A sink is a configuration record in the Catalog. Each sink has an associated **producer adapter** that transforms entries into a sink-native representation and delivers or materializes it.

Sinks may be:
- **push sinks** (Claptrap actively sends entries, e.g. webhook/Slack/email)
- **pull sinks** (Claptrap maintains a representation that downstream clients fetch, e.g. an RSS feed endpoint)

### Subscription

A rule that links sinks to sources based on **tag matching**. Subscriptions are stored as `{sink_id, tags[]}` — sinks subscribe to tags, not to specific sources.

When entries are consumed, the Producer.Router matches each entry's resolved tag set against subscription tag sets using array overlap queries (`entry.tags && subscription.tags`). Every subscription with at least one overlapping tag receives the entry for delivery to its sink.

**Automatic routing**: Adding a new source tagged `["tech"]` automatically routes its entries to all sinks with subscriptions containing `"tech"`. No explicit source→sink wiring required.

In v1, tag matching uses ANY semantics (array overlap). This is the sole routing mechanism; there is no complex filter DSL.

### Tag

A string label used as the sole routing dimension in Claptrap. Tags connect sources to sinks indirectly — they appear on sources and entries, and are matched by subscriptions to determine delivery targets.

- **Source tags**: Configured on source resources. These are **inherited** by every entry consumed from that source.
- **Content-derived tags**: Applied by consumer adapters during consumption based on entry content, upstream metadata, or adapter-specific classification logic.
- **Entry tags**: The persisted tag set on an entry, computed at consume time as the **union** of inherited source tags and content-derived tags. This resolved set is canonical — it is used for all downstream routing and user-facing organization.

Tag resolution is a write-time concern. Once an entry's tags are persisted, the router operates entirely on the entry's tag set without needing to look up the source.

## Subsystems

### Catalog

The central registry. Connects to PostgreSQL to manage all resource definitions (sources, sinks, subscriptions, entries). Vends and lists records to surrounding processes.

### Consumer

A worker process that consumes entries from a source. One consumer process per configured source. The consumer owns the lifecycle: scheduling, error handling, backoff, and persistence. It delegates the protocol-specific work (parsing RSS XML, calling the YouTube API, verifying webhook signatures) to a **consumer adapter**.

Consumers may be triggered by internal scheduling (pull sources) or by API/webhook handlers that enqueue work (push sources). In both cases, the Consumer worker owns lifecycle concerns: backoff, deduplication, persistence, and emitting consumption events.

### Producer

A worker process that publishes entries to a sink. One producer process per configured sink. The producer owns the lifecycle: receiving entries from the Router, formatting, and either delivering them (push sinks) or materializing a representation for later retrieval (pull sinks), plus retry/backoff. It delegates the protocol-specific work (generating RSS XML, POSTing to a webhook) to a **producer adapter**.

### API

The external HTTP interface. Exposes REST endpoints for clients outside the cluster. Implemented via Phoenix (`ClaptrapWeb.Endpoint`).

### MCP

The AI agent interface. A Model Context Protocol server (`ClaptrapWeb.MCP.Server`) that bridges agents to the same Catalog and API functions the REST API uses.

## Adapters

An adapter is a pure module (no process, no state) that knows how to transform between the Entry format and a specific external protocol. Adapters implement a behaviour and are called by workers to do protocol-specific work.

### Consumer Adapter

Inbound adapter. Transforms source-native format into Entry attributes. Consumer adapters implement the `Consumer.Adapter` behaviour.

### Producer Adapter

Outbound adapter. Transforms entries into sink-native format for delivery. Producer adapters implement the `Producer.Adapter` behaviour.

### Protocol Overlap

Some protocols (e.g., RSS) can be both a source and a sink. "RSS" is a protocol, not a role. An RSS feed is a source when Claptrap reads it (Consumer + `Consumer.Adapter.RSS`). An RSS feed is a sink when Claptrap generates one (Producer + `Producer.Adapter.RSS`). The adapter implementations are separate modules because the operations are different (parsing vs. generating), but they share understanding of the same protocol.

## Status & Organization

### Status

The reading state of an entry:

- **Unread**: New content not yet reviewed
- **In Progress**: Currently being read/consumed
- **Read**: Completed
- **Archived**: Kept for reference

## See Also

- [Architecture](architecture.md) for system design details
- [Integrations](integrations.md) for supported source and sink implementations
