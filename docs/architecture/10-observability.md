# Observability

Claptrap uses `:telemetry`, structured logging, Prometheus-oriented metrics export, and lightweight HTTP endpoints to make the system observable.

## Telemetry Model

The architecture separates observability into three distinct channels: **logging**, **traces**, and **metrics**. Each serves a specific purpose and avoids duplication of concerns.

### Logging

Structured logs capture contextual information for diagnosis and forensics. All log entries include standard metadata fields:

- `source_id` — identifies the source being processed
- `sink_id` — identifies the destination sink
- `timestamp` — ISO8601 timestamp
- `level` — log level (debug, info, warn, error)

Key logging events:

- Consumer start/stop for a source
- Producer delivery attempts and outcomes
- Retry events with failure reasons
- Deduplication decisions (new vs duplicate entries)
- Configuration changes or reloads
- Database connection issues
- HTTP endpoint access

Logs should include enough context to reconstruct the sequence of events for a given source or sink without requiring correlation with metrics.

### Traces

Traces capture timing and duration data using `:telemetry` span events. Duration metrics are **not** duplicated as Prometheus metrics — they exist only in traces.

| Event | Measurements | Metadata |
| --- | --- | --- |
| `[:claptrap, :consumer, :consume, :start]` | `system_time` | `source_id`, `source_type` |
| `[:claptrap, :consumer, :consume, :stop]` | `duration` (native time) | `source_id`, `source_type`, `entry_count` |
| `[:claptrap, :consumer, :consume, :exception]` | `duration` | `source_id`, `kind`, `reason`, `stacktrace` |
| `[:claptrap, :producer, :delivery, :start]` | `system_time` | `sink_id`, `entry_count` |
| `[:claptrap, :producer, :delivery, :stop]` | `duration` | `sink_id`, `entry_count`, `status` |
| `[:claptrap, :producer, :delivery, :exception]` | `duration` | `sink_id`, `kind`, `reason`, `stacktrace` |
| `[:claptrap, :catalog, :dedup, :start]` | `system_time` | `source_id`, `entry_count` |
| `[:claptrap, :catalog, :dedup, :stop]` | `duration` | `source_id`, `total`, `new`, `duplicate` |

Traces follow the `:telemetry.span/3` pattern with `:start`, `:stop`, and `:exception` events. Exporters can convert these to OpenTelemetry spans or other distributed tracing formats.

### Metrics

Metrics capture **domain state** and **throughput** — not timing. All timing is handled by traces. Metrics are exported via Prometheus and focus on:

1. **Application domain metrics** — operational state of the ingestion pipeline
2. **Bandit HTTP server metrics** — request handling instrumentation

#### Application Domain Metrics

| Metric | Type | Labels | Description |
| --- | --- | --- | --- |
| `claptrap_consumer_entries_total` | Counter | `source_id`, `source_type` | Total entries consumed per source |
| `claptrap_consumer_errors_total` | Counter | `source_id`, `reason` | Total consumer errors by reason |
| `claptrap_consumer_consecutive_failures` | Gauge | `source_id` | Current consecutive failure count |
| `claptrap_producer_deliveries_total` | Counter | `sink_id`, `status` | Total deliveries by outcome (success/failure) |
| `claptrap_producer_retries_total` | Counter | `sink_id`, `attempt` | Total retry attempts per sink |
| `claptrap_catalog_dedup_total` | Counter | `source_id`, `outcome` | Deduplication results (new/duplicate) |
| `claptrap_catalog_entries_total` | Gauge | `source_id` | Current entry count in catalog per source |
| `claptrap_sources_active` | Gauge | — | Number of currently active sources |
| `claptrap_sinks_active` | Gauge | — | Number of currently active sinks |

#### Bandit HTTP Server Metrics

Bandit provides instrumented telemetry events for HTTP request handling. These are exposed via the Prometheus endpoint:

| Metric | Type | Labels | Description |
| --- | --- | --- | --- |
| `bandit_requests_total` | Counter | `method`, `path`, `status` | Total HTTP requests served |
| `bandit_active_connections` | Gauge | — | Currently active HTTP connections |
| `bandit_request_errors_total` | Counter | `reason` | Total request errors by reason |

These events cover the core operational loops:

- consumption throughput and error rates
- delivery outcomes and retry pressure
- deduplication effectiveness
- pipeline scale (active sources/sinks)
- HTTP endpoint health and request patterns

## Built-in Observability Tooling

### Prometheus metrics endpoint

Telemetry events are exported through a Prometheus-compatible `/metrics` endpoint.

### Health and readiness endpoints

The HTTP layer exposes:

- `GET /health` for liveness
- `GET /ready` for readiness, including dependency checks such as database reachability

### Logger

The architecture assumes structured logging with metadata so that source IDs, sink IDs, and failure reasons can be correlated during debugging and operations.

### Telemetry subscribers

The system can subscribe to Ecto query events, Bandit/Plug request instrumentation, and the custom Claptrap events above.

## Operational Intent

The observability model is lightweight but appropriate for a v1 daemon, organized into three complementary channels:

- **Traces** — capture timing and latency across all operations
- **Metrics** — expose domain state, throughput counters, and HTTP instrumentation for Prometheus
- **Logs** — provide contextual diagnostics and event reconstruction

This separation avoids duplication (e.g., durations are trace-only, not metrics) while maintaining operational clarity. The model is deliberate in scope:

- No distributed tracing backend required initially — trace events can be logged or exported later
- Prometheus-compatible metrics for alerting and dashboards
- Structured logs for debugging and forensics
- Health endpoints for orchestration

It avoids introducing a heavy observability stack into the core design while leaving room for OpenTelemetry exporters, Grafana dashboards, or log aggregation as operational needs evolve.
