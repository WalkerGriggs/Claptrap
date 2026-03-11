# Sinks

This document defines sinks as Catalog-owned resources.

## Purpose

A sink is a configured delivery target that Claptrap can route processed content to.

Examples may include:

- email delivery targets
- webhook destinations
- chat or messaging endpoints
- file or export targets
- future external integrations

A sink describes **where content goes after normalization and routing**.

## Responsibilities

The Catalog owns sinks so the rest of the system has a stable registry for delivery configuration.

This includes:

- creating and updating sink definitions
- validating shared sink structure
- delegating sink-type-specific validation to producer adapters
- resolving sink configuration for delivery workers

## Operational role

Producer-side components use sinks as the durable source of truth for delivery behavior.

Examples:

- `Catalog.sinks_for_source(source_id)` helps `Producer.Router` determine delivery targets
- `Catalog.get_sink!(sink_id)` lets `Producer.Workers` load the configuration needed to perform delivery

## Boundary semantics

A sink is configuration, not delivery state.

That distinction matters because:

- the sink resource should remain the durable declarative target definition
- transient delivery attempts, retries, and failures belong to runtime execution or job state

## What a sink should contain

The exact schema is not yet fixed here, but a sink will generally include:

- a primary key
- a sink type or adapter kind
- normalized destination configuration
- enabled or disabled state
- timestamps and lifecycle metadata

## Validation boundary

As with sources:

- the Catalog owns the resource lifecycle
- the selected producer adapter validates sink-specific configuration details

This keeps the control-plane interface stable while allowing each sink type to evolve independently.

## Relationship to subscriptions

Sinks are not directly attached to entries. They are selected through subscriptions.

That means:

- a sink can receive content from multiple sources
- routing policy remains explicit and inspectable
- producer behavior can stay decoupled from consumption details

## Open design questions

Likely follow-up design work includes:

- how sink credentials are referenced and rotated
- whether per-sink formatting preferences belong on the sink or elsewhere
- whether delivery rate limits should be modeled declaratively on the sink
- how sink health or disablement should be surfaced operationally
