# Architecture Topics

This directory breaks `../architecture.md` into focused topic documents so each major architectural concern can be discussed independently.

## Documents

- `01-system-overview.md` — architectural rationale, subsystem decomposition, top-level data flow, and the Plug + Bandit web-layer decision
- `02-supervision-tree.md` — process hierarchy, restart strategies, and failure domains
- `03-catalog.md` — central registry responsibilities and persistence boundary
- `04-consumer.md` — consumption model, worker lifecycle, retries, adapters, and push-source handling
- `05-producer.md` — routing, delivery workers, retries, adapters, and ordering guarantees
- `06-api-and-mcp.md` — HTTP API, webhook boundaries, and MCP interface design over HTTP/SSE
- `07-pubsub-and-data-flow.md` — internal event bus, topic contracts, and subsystem boundaries
- `08-database-and-schema.md` — tables, deduplication model, JSONB usage, and persistence concerns
- `09-config-and-secrets.md` — compile-time vs runtime config, bootstrapping, and credential handling
- `10-observability.md` — telemetry, logging, metrics, health endpoints, and operational visibility
- `11-reliability-and-oban.md` — pure OTP reliability tradeoffs and when to introduce Oban
- `12-deployment-and-scaling.md` — release model, single-node deployment, and future clustering posture
- `13-project-structure.md` — source tree layout and dependency mapping to runtime architecture
- `14-open-questions.md` — unresolved design decisions and future correctness tradeoffs
