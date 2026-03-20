defmodule Claptrap.Catalog do
  @moduledoc false

  import Ecto.Query

  alias Claptrap.Repo
  alias Claptrap.Schemas.{Entry, Sink, Source, Subscription}

  # Sources

  def list_sources(opts \\ []) do
    Source
    |> maybe_filter_enabled(opts[:enabled])
    |> Repo.all()
  end

  def get_source!(id), do: Repo.get!(Source, id)

  def create_source(attrs) do
    %Source{}
    |> Source.changeset(attrs)
    |> Repo.insert()
  end

  def update_source(%Source{} = source, attrs) do
    source
    |> Source.changeset(attrs)
    |> Repo.update()
  end

  def delete_source(%Source{} = source), do: Repo.delete(source)

  # Sinks

  def list_sinks(opts \\ []) do
    Sink
    |> maybe_filter_enabled(opts[:enabled])
    |> Repo.all()
  end

  def get_sink!(id), do: Repo.get!(Sink, id)

  def create_sink(attrs) do
    %Sink{}
    |> Sink.changeset(attrs)
    |> Repo.insert()
  end

  def update_sink(%Sink{} = sink, attrs) do
    sink
    |> Sink.changeset(attrs)
    |> Repo.update()
  end

  def delete_sink(%Sink{} = sink), do: Repo.delete(sink)

  # Subscriptions

  def list_subscriptions(opts \\ []) do
    Subscription
    |> maybe_filter_by(:sink_id, opts[:sink_id])
    |> Repo.all()
  end

  def create_subscription(attrs) do
    %Subscription{}
    |> Subscription.changeset(attrs)
    |> Repo.insert()
  end

  def get_subscription!(id), do: Repo.get!(Subscription, id)

  def delete_subscription(%Subscription{} = subscription), do: Repo.delete(subscription)

  def subscriptions_for_tags(tags) when is_list(tags) do
    from(s in Subscription, where: fragment("? && ?", s.tags, ^tags))
    |> Repo.all()
  end

  # Entries for sink (used by producer adapters for materialization)

  def entries_for_sink(sink_id, opts \\ []) do
    limit = opts[:limit] || 50

    entry_ids =
      from(e in Entry,
        join: s in Subscription,
        on: fragment("? && ?", e.tags, s.tags),
        where: s.sink_id == ^sink_id,
        distinct: e.id,
        select: e.id
      )

    from(e in Entry,
      where: e.id in subquery(entry_ids),
      order_by: [desc: e.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  # Entries

  def list_entries(opts \\ []) do
    Entry
    |> maybe_filter_by(:status, opts[:status])
    |> maybe_filter_by(:source_id, opts[:source_id])
    |> maybe_limit(opts[:limit])
    |> maybe_order(opts[:order])
    |> Repo.all()
  end

  def get_entry!(id), do: Repo.get!(Entry, id)

  def create_entry(attrs) do
    %Entry{}
    |> Entry.changeset(attrs)
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:external_id, :source_id])
  end

  def update_entry(%Entry{} = entry, attrs) do
    entry
    |> Entry.changeset(attrs)
    |> Repo.update()
  end

  # Private helpers

  defp maybe_filter_enabled(query, nil), do: query
  defp maybe_filter_enabled(query, value), do: where(query, [q], q.enabled == ^value)

  defp maybe_filter_by(query, _field, nil), do: query
  defp maybe_filter_by(query, :status, value), do: where(query, [q], q.status == ^value)
  defp maybe_filter_by(query, :source_id, value), do: where(query, [q], q.source_id == ^value)
  defp maybe_filter_by(query, :sink_id, value), do: where(query, [q], q.sink_id == ^value)

  defp maybe_limit(query, nil), do: query
  defp maybe_limit(query, value), do: limit(query, ^value)

  defp maybe_order(query, nil), do: query
  defp maybe_order(query, {direction, field}), do: order_by(query, [q], [{^direction, ^field}])
  defp maybe_order(query, field) when is_atom(field), do: order_by(query, [q], asc: ^field)
end
