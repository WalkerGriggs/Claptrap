# Subscriptions

## Description

A subscription is a Catalog-owned routing rule that determines how entries are delivered to sinks based on tag matching.

## Motivation

Subscriptions make producer routing policy explicit. Consumers consume content from sources, and producers deliver content to sinks, but neither sources nor sinks should own the routing decision.

A subscription is the durable and queryable record that tells routers where to direct entries. It decouples sources from sinks entirely — neither resource references the other. Tags are the sole routing dimension.

## Technical details

A subscription binds a sink to a set of tags. When entries are consumed, the Producer.Router matches each entry's resolved tag set against all active subscriptions using array overlap (ANY semantics). Every subscription with at least one overlapping tag receives the entry for delivery.

There is no `source_id` on a subscription. Sources and sinks are completely decoupled. The only thing connecting them is the tag namespace.

### Tag resolution

Tags on entries are resolved at consume time as the **union** of two sources:

1. **Inherited tags** — tags configured on the source. When a consumer consumes entries from a source, every entry inherits that source's tags automatically.
2. **Content-derived tags** — tags applied by the consumer adapter based on entry content, upstream metadata, or adapter-specific classification logic.

The entry's persisted `tags` field is the union of both sets. Once written, this is the canonical tag set used for all downstream routing and querying.

Tag resolution is a write-time concern. The router never needs to look up the source's tags at delivery time — it operates entirely on the entry's resolved tag set.

### Routing semantics

Routing uses ANY matching (PostgreSQL array overlap via the `&&` operator). A subscription with tags `["tech"]` matches any entry whose resolved tag set contains `"tech"`, regardless of what other tags the entry carries.

This means:

- A source tagged `["tech", "news"]` produces entries with at least `["tech", "news"]`.
- A subscription with tags `["tech"]` matches those entries because `["tech"] && ["tech", "news"]` is true.
- A subscription with tags `["podcasts"]` does not match unless the adapter also tagged the entry with `"podcasts"`.

### Automatic routing

Adding a new source tagged `["tech"]` automatically routes its entries to all sinks with subscriptions containing `"tech"`. No explicit source-to-sink wiring is required.

Similarly, adding a new subscription for `["tech"]` on a sink immediately begins matching entries from any source that produces `"tech"`-tagged content. The routing graph is fully declarative and reactive.

### Subscription lifecycle

A subscription may be enabled or disabled. Disabled subscriptions are ignored during routing but retained for auditability and re-enablement.

### Catalog API

Producer-side routing logic consumes subscriptions to determine where entries should be delivered. The primary query interface is:

- `Catalog.subscriptions_for_tags(tags)` — given an entry's resolved tag set, return all enabled subscriptions with overlapping tags. This resolves to a list of sink IDs that should receive the entry.

### Relationship to other resources

Subscriptions govern the flow of entries, but entries do not own subscriptions. Entries represent normalized content facts produced by consumers from sources. Subscriptions represent the policy that tells producers which sinks should receive those entries.


Sources influence routing only indirectly, through tag inheritance onto entries. Sinks receive entries only through subscription matches. The subscription is the sole routing primitive.

## Ecto schema shape

```elixir
defmodule Claptrap.Schemas.Subscription do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "subscriptions" do
    belongs_to :sink, Claptrap.Schemas.Sink
    field :tags, {:array, :string}
    field :enabled, :boolean, default: true

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [:sink_id, :tags, :enabled])
    |> validate_required([:sink_id, :tags])
    |> validate_length(:tags, min: 1)
    |> foreign_key_constraint(:sink_id)
  end
end
```

## Routing query

The router resolves delivery targets for a given entry by matching the entry's resolved tags against subscription tag sets:

```elixir
def subscriptions_for_tags(entry_tags) do
  from(s in Subscription,
    where: fragment("? && ?", s.tags, ^entry_tags),
    where: s.enabled == true,
    select: s.sink_id
  )
  |> Repo.all()
end
```

A GIN index on `subscriptions.tags` makes this overlap query efficient.

## Migration notes

The subscriptions table requires:

- A foreign key from `sink_id` to `sinks.id`
- A GIN index on the `tags` column for efficient `&&` (array overlap) queries
- An index on `sink_id` for reverse lookups