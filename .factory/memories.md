# Project Memories — Claptrap

## Architecture Decisions
- Elixir/OTP application: concurrent content
  ingestion and delivery daemon
- Plug + Bandit for HTTP (not Phoenix web layer);
  Phoenix.PubSub retained as internal event bus
- PostgreSQL via Ecto for persistence; JSONB for
  adapter-specific config
- Cloak.Ecto for credential encryption at rest
  (Claptrap.Vault)
- One GenServer worker per source (Consumer) and
  per sink (Producer)
- Tag-based subscription routing via array overlap
- Deduplication via ON CONFLICT DO NOTHING on
  (external_id, source_id)

## Subsystem Boundaries
- Catalog: central registry, persistence boundary,
  domain API
- Consumer: source ingestion, one worker per source,
  adapter-based
- Producer: sink delivery, one worker per sink,
  PubSub-driven routing
- API: REST endpoints + webhook receivers + pull
  sink endpoints (Plug/Bandit)
- MCP: AI agent interface over HTTP/SSE, same
  domain functions as REST

## Key PubSub Topics
- `entries:new` — Consumer.Workers → Producer.Router
- `catalog:changed` — Catalog.Server → Coordinator,
  Router

## Supervision Strategy
- Consumer.Supervisor: :rest_for_one (Coordinator
  depends on WorkerSupervisor)
- Producer.Supervisor: :rest_for_one (Router depends
  on WorkerSupervisor)
- WorkerSupervisors: :one_for_one (workers are
  independent)
- API.Supervisor: :one_for_one (HTTP and MCP
  independent)

## Known Constraints
- Retries are in-memory; lost on restart (Oban
  migration path documented)
- v1 is single-node; distributed Erlang deferred
- Entry ordering uses ingested_at with usec
  precision
