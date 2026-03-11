defmodule Claptrap.PubSub do
  @moduledoc """
  Thin wrapper around Phoenix.PubSub for internal event routing.

  Topics:
    - "entries:new"      — Consumer.Workers → Producer.Router
    - "catalog:changed"  — Catalog.Server → Coordinator, Router
  """

  @pubsub __MODULE__

  @topic_entries_new "entries:new"
  @topic_catalog_changed "catalog:changed"

  def topic_entries_new, do: @topic_entries_new
  def topic_catalog_changed, do: @topic_catalog_changed

  def subscribe(topic) do
    Phoenix.PubSub.subscribe(@pubsub, topic)
  end

  def broadcast(topic, message) do
    Phoenix.PubSub.broadcast(@pubsub, topic, message)
  end

  def broadcast!(topic, message) do
    Phoenix.PubSub.broadcast!(@pubsub, topic, message)
  end
end
