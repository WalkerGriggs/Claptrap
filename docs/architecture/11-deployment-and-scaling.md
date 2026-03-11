# Deployment and Scaling

This document covers the deployment model proposed by the architecture and the limited scaling story contemplated for later phases.

## Phase 1: Single Release

Elixir compiles to a **release**: a self-contained directory containing the BEAM VM, compiled bytecode, and all runtime dependencies.

That means:

- no separate Elixir installation is required on the target machine
- a single container deployment is straightforward
- PostgreSQL is the primary external dependency
- the HTTP layer runs as a Plug application served by Bandit

Runtime configuration such as database URLs and secrets is loaded from `file 'Claptrap/config/runtime.exs'` at boot, not compile time.

The practical benefit is that the same release artifact can be deployed to development and production environments by changing environment variables rather than rebuilding.

## Phase 2: Distributed Erlang, If Ever Needed

If Claptrap ever needs to run across multiple machines, the BEAM already has built-in node clustering.

The architecture notes:

- nodes can be connected directly
- Phoenix.PubSub can distribute messages across connected Erlang nodes
- Ecto connections remain node-local, with each node maintaining its own database pool

## Scaling Posture

The design is intentionally conservative.

It does not optimize for horizontal scale first. It optimizes for:

- operational simplicity
- correct failure isolation
- a personal-tool deployment model

For the stated problem, that is the right default. A single-node release with PostgreSQL is enough until real evidence says otherwise.
