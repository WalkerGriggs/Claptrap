# Entities

This document has been split into focused Catalog resource documents.

## Catalog resource documents

- `catalog/entries.md` — normalized content entries, type system, timestamps, provenance, deduplication, and typed payloads
- `catalog/sources.md` — upstream source resources and their role in consumption
- `catalog/sinks.md` — delivery target resources and their role in producer execution
- `catalog/subscriptions.md` — routing relationships between sources and sinks

## Why the split

The original entries document mixed two concerns:

- the detailed structure of the `Entry` resource
- the broader question of how Catalog-owned entities should be organized

The split keeps all entry types together in one place while separating them from other Catalog resources.

That preserves the important modeling choice that:

- entries are one unified resource with one `type` enum and one shared envelope
- sources, sinks, and subscriptions are separate Catalog resources with different lifecycle and ownership concerns

## Recommended reading order

1. `catalog/entries.md`
2. `catalog/sources.md`
3. `catalog/sinks.md`
4. `catalog/subscriptions.md`
