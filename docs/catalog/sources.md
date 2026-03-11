# Sources

This document defines sources as Catalog-owned resources.

## Purpose

A source is a configured upstream content origin that Claptrap knows how to consume.

Examples include:

- an RSS or Atom feed
- a YouTube channel or playlist
- a Zotero library
- a Goodreads account or shelf
- an inbound webhook endpoint

Sources are not entries. A source describes **where content comes from** and **how Claptrap should talk to that upstream system**.

## Responsibilities

The Catalog owns sources as durable resources so that other subsystems can rely on a stable source definition for:

- worker bootstrap
- scheduling and polling
- adapter selection
- configuration validation
- source lifecycle management

## Source identity

A source has a Claptrap-owned identity independent of upstream item identity.

Important distinction:

- `source.id` identifies the configured integration instance inside Claptrap
- `entry.external_id` identifies a specific upstream item within that source's namespace

This separation is critical for idempotency and worker management.

## What a source should contain

The exact schema is not yet defined here, but a source resource will typically include:

- a primary key
- a source type or adapter kind
- normalized configuration needed by the consumer adapter
- operational state such as enabled or disabled
- scheduling or polling metadata where applicable
- timestamps and lifecycle metadata

## Validation boundary

The Catalog is responsible for creating and updating sources, but it should not hardcode the details of every upstream protocol.

Instead:

- the Catalog enforces shared structural invariants
- the selected adapter validates source-type-specific configuration

That keeps Catalog as the control-plane boundary without turning it into a grab bag of protocol-specific parsing logic.

## Operational role

Consumers use sources to determine which workers to run and how to normalize upstream content.

Examples:

- `Catalog.list_sources(filters)` lets `Consumer.Coordinator` bootstrap workers
- source change events can tell the consumer subsystem to start, stop, or reconfigure workers

## Relationship to entries

A source may emit many entries.

An entry records content discovered from a source. The source itself records the durable upstream integration definition.

That means:

- source lifecycle is about configuration and consumption behavior
- entry lifecycle is about normalized discovered content

## Relationship to subscriptions

Sources do not participate directly in subscriptions. Subscriptions match against entry tags, not source resources.

However, sources influence routing indirectly: tags configured on a source are inherited by every entry consumed from it. This means adding a tag to a source automatically changes which subscriptions match its entries. Routing policy still belongs to subscriptions — sources only contribute to the tag set that subscriptions evaluate.

## Open design questions

This document intentionally stops short of locking down the full source schema. Remaining design questions likely include:

- how much protocol configuration should be normalized vs stored adapter-specifically
- how polling cadence is modeled
- how webhook secrets or credentials are referenced
- whether operational checkpoints belong on the source row or in adapter-owned state
