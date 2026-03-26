# Producer

Delivers ingested entries to sinks (output destinations) using a
PubSub-driven router and per-sink workers. Supports both push
(send to external service) and pull (materialize for on-demand
retrieval) delivery modes via a behaviour-based adapter pattern.

## Architecture

```
PubSub "entries:new"
  │
  ▼
Router ──▶ subscriptions_for_tags() ──▶ group by sink
  │
  ├──▶ Worker (pull)  ── Adapter.materialize() ──▶ ETS
  └──▶ Worker (push)  ── Adapter.push() ─────────▶ External API
```

## Supervisor tree

```
Producer.Supervisor (:rest_for_one)
  │
  ├── WorkerSupervisor (DynamicSupervisor, :one_for_one)
  │     ├── Worker (sink A)
  │     ├── Worker (sink B)
  │     └── ...
  │
  └── Router (GenServer)
```

The `:rest_for_one` strategy means if the `WorkerSupervisor`
crashes, the Router also restarts (and re-bootstraps workers).
If only the Router crashes, existing workers keep running. The
ETS table `:claptrap_rss_feeds` is owned by the Supervisor
process itself, so it survives worker and router crashes.

## Subdirectories

- **`adapters/`** — Concrete implementations of the
  `Claptrap.Producer.Adapter` behaviour. Currently only
  `rss_feed` (generates RSS 2.0 XML, stores in ETS).

### RSS sink config requirements

For sinks with `type: "rss"`, the adapter requires:

- `config["description"]` — feed description text
- `config["link"]` — non-empty absolute URL (must include scheme and host)
- `config["max_entries"]` — optional positive integer limit

## Key concepts

The router performs tag-based matching to connect entries to
sinks:

```
Entry (tags: ["tech", "elixir"])
  │
  ▼
Subscription A (tags: ["elixir"], sink_id: 1)  ← match
Subscription B (tags: ["rust"],   sink_id: 2)  ← no match
  │
  ▼
Worker for sink 1 receives the entry
```

Matching uses `MapSet.disjoint?/2` — if an entry's tags and a
subscription's tags are *not* disjoint, the entry is routed to
that subscription's sink.

The adapter behaviour defines the contract for sink types:

```elixir
@callback mode() :: :push | :pull
@callback push(Sink.t(), [Entry.t()]) :: :ok | {:error, term()}
@callback materialize(Sink.t(), [Entry.t()]) :: :ok | {:error, term()}
@callback validate_config(map()) :: :ok | {:error, String.t()}
```

Workers emit telemetry events under `[:claptrap, :producer, :]`:

- `[:claptrap, :producer, :delivery]` — sink_id, entry_count,
  status
- `[:claptrap, :producer, :retry]` — sink_id, attempt, delay

## Notes

- The ETS table `:claptrap_rss_feeds` is created by the
  Supervisor (not the adapter) with `read_concurrency: true` and
  `:public` access, so it survives individual worker crashes.
- On startup, the Router bootstraps a worker for every enabled
  sink. Pull-mode workers immediately materialize an initial
  (empty) feed.
- Retry uses exponential backoff (`500ms × 2^attempt + jitter`,
  capped at 30s, max 5 retries). Failed batches are dropped
  after exhausting retries.
- Adding a new sink type requires implementing
  `Claptrap.Producer.Adapter` and adding a clause to
  `Worker.adapter_for_type/1`.
