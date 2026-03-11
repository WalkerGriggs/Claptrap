# Consumer

The Consumer subsystem consumes external sources, whether pull- or push-triggered, normalizes their content into entries, and persists them to the database.

## Process Model

**One worker per source.** Each RSS feed, YouTube subscription, Zotero library, and similar source gets its own GenServer process.

This provides:

- **Isolated state**: each source has its own last-consume timestamp, error count, and backoff timer
- **Isolated failures**: one broken source does not affect others
- **Independent scheduling**: pull sources manage their own poll interval
- **Natural backpressure**: each worker implements its own rate limiting and retry behavior

## Worker Lifecycle

Each worker follows this lifecycle:

1. **init**
   - Load source config from Catalog
   - Decrypt credentials
   - Initialize worker state
2. **consume cycle**
   - Fetch or accept input via the consumer adapter
   - Normalize raw content into Entry structs
   - Deduplicate via `Catalog.create_entry` using Ecto `ON CONFLICT DO NOTHING`
   - Broadcast `{:entries_ingested, source_id, entries}` to PubSub
   - For pull sources, schedule the next poll
3. **restart**
   - If the worker crashes, the DynamicSupervisor restarts it with fresh state
   - On restart, the worker immediately triggers a consume cycle instead of waiting for the next normal poll interval

That immediate post-restart poll is an important operational choice: it minimizes recovery latency after transient failures.

## Retry on Poll Failure

When a consume cycle fails because of HTTP errors, parse failures, timeouts, or similar transient conditions, the worker retries up to **5 times** with exponential backoff:

- **Initial backoff**: 500ms
- **Formula**: `min(500ms × 2^attempt + jitter, 30s)` where jitter is a small random value from 0–100ms
- **Progression**: approximately 500ms → 1s → 2s → 4s → 8s, plus jitter, capped at 30s
- **On exhaustion**: log the error with source metadata, skip the current cycle, and resume the normal poll schedule

Retries are scoped to a single consume cycle. The retry counter resets on each new scheduled poll.

## Consumer.Adapter Behaviour

All source types implement the `Consumer.Adapter` behaviour.

A source can be pull-triggered or push-triggered, and the adapter exposes the appropriate entry point.

```markdown
@callback mode() :: :pull | :push
@callback fetch(source) :: {:ok, [raw_attrs]} | {:error, term()}
@callback ingest(source, input) :: {:ok, [raw_attrs]} | {:error, term()}
@callback validate_config(config) :: :ok | {:error, String.t()}
```

- `mode/0` indicates whether the coordinator schedules polls for this source
- `fetch/1` is used for pull sources
- `ingest/2` is used for push sources such as webhook payload consumption

Adapters are responsible for:

- Fetching raw content from the external source for pull modes
- Parsing and normalizing source-native data into entry attributes
- Handling source-specific concerns such as pagination, rate limits, and authentication

Adapters are pluggable. RSS, YouTube, Zotero, and Webhook implementations all satisfy the same behaviour.

## Error Handling Philosophy

Consumer adapters follow a "let it crash" model, but with a clear distinction between *wrong*, *incomplete*, and *transient* conditions.

### Wrong → raise and crash

Examples include:

- authentication failures caused by invalid credentials
- invalid source configuration
- violated invariants
- programmer bugs

These indicate the system is in a state it should not be in. Retrying will not fix them. The adapter raises, the worker crashes, and the supervisor restarts it from clean state.

### Incomplete → heal and continue

Examples include:

- missing `published_at`
- missing author
- truncated description

This data may simply not exist upstream. Adapters should fill sensible defaults, skip optional fields, and fall back when necessary. For example, if `published_at` is absent, use `ingested_at`.

### Transient failures → return `{:error, reason}`

Examples include:

- HTTP 5xx
- timeouts
- connection refused

These are expected operational conditions. The adapter returns an error tuple and the worker applies retry and backoff logic. These are not crash-worthy.

## Coordinator Role

`Consumer.Coordinator` is responsible for:

- bootstrapping workers for all enabled sources at init time
- periodically querying the Catalog for pull sources that are due to poll
- sending `:poll` messages to the appropriate workers

Push-based sources do not rely on scheduled polling. Instead, the API layer receives inbound webhook traffic and enqueues consumption work into the matching Consumer worker.
