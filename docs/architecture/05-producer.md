# Producer

The Producer subsystem packages entries from the database and delivers them to configured sinks.

## Process Model

**One worker per sink.** Each combined RSS feed, webhook endpoint, email digest, and similar sink gets its own GenServer process.

This mirrors the Consumer design: isolate state, isolate failures, and make per-sink retry behavior explicit.

## Producer.Router: Event-Driven Routing

`Producer.Router` is a single GenServer that owns the filtering and dispatch logic for entry delivery.

### Responsibilities

1. **Subscribe**
   - On init, subscribe to the PubSub topic `entries:new`
2. **Route and filter**
   - When `{:entries_ingested, source_id, entries}` arrives, query the Catalog for matching subscriptions
   - Match each entry's resolved tag set against subscription tags
   - Send `{:deliver, entries}` to each matching `Producer.Worker`
3. **Fire-and-forget dispatch**
   - Dispatch once and move on
   - Do not track delivery state or retry on behalf of workers
4. **Preserve decoupling**
   - Consumer workers do not know about sinks
   - The PubSub topic is the contract boundary between consumption and delivery

### Tag-based subscription model

For v1, routing is intentionally simple:

- Entries carry a resolved tag set computed at consume time as the union of source-inherited tags and adapter-applied content tags
- Sinks subscribe to tags via subscriptions
- The Router resolves interest by matching each entry's tags against subscription tag sets using array overlap

This avoids introducing a more complex filter DSL before it is needed.

### Why a separate Router exists

The Router isolates delivery selection from consumption. Consumers publish events; Producers decide how those events fan out. That separation keeps the subsystems independently evolvable.

## Producer.Worker: Delivery with Retry

Each producer worker is solely responsible for delivering entries to its sink and retrying on failure.

### Lifecycle

1. **Receive**
   - Accept `{:deliver, entries}` cast from the Router
2. **Package**
   - Call the appropriate `Producer.Adapter` to format entries for the sink
3. **Deliver**
   - For push sinks, send to the external destination such as webhook, Slack, or email
   - For pull sinks, materialize or update a representation that will later be served over HTTP, such as RSS XML
4. **Retry on failure**
   - Retry with exponential backoff
   - On exhaustion, log the failure and drop the batch
   - The Router is not involved in retry management
5. **Telemetry**
   - Emit telemetry events for success, failure, and retry attempts

### Retry strategy

- Exponential backoff: `500ms × 2^attempt + jitter`
- Maximum backoff: 30s
- Maximum attempts: 5
- In-memory queue: Erlang `:queue`

This is deliberately simple, but it has an important limitation: retries are lost on restart. If guaranteed delivery is required, the architecture recommends migrating this part of the pipeline to Oban.

## Producer.Adapter Behaviour

All sink types implement the `Producer.Adapter` behaviour:

```markdown
@callback mode() :: :push | :pull
@callback push(sink, entries) :: :ok | {:error, term()}
@callback materialize(sink, entries) :: :ok | {:error, term()}
@callback validate_config(config) :: :ok | {:error, String.t()}
```

- `mode/0` indicates whether the sink is push-delivered or pull-served
- `push/2` is used for push sinks
- `materialize/2` is used for pull sinks, such as generating RSS XML and storing it

Producer adapters are responsible for:

- Packaging entries into sink-native formats or representations such as RSS XML, webhook JSON payloads, or email HTML
- Delivering formatted output to sink endpoints for push sinks
- Materializing output for later retrieval for pull sinks
- Handling sink-specific concerns such as authentication and rate limits

## Entry Ordering

Entries must be delivered to sinks **in consumption order**.

Each entry is timestamped at consume time using `ingested_at` with microsecond precision. The Router preserves ordering when dispatching to Producer workers, and workers deliver entries in the order received.

For v1, `ingested_at` with type `:utc_datetime_usec` is the ordering key. If timestamp precision becomes insufficient, for example because of concurrent consumption collisions or future clock skew in distributed deployments, a Lamport clock or monotonic per-sink sequence number can be added as a tiebreaker without changing the external delivery contract.
