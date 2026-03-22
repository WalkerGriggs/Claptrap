defmodule Claptrap.API.Serializers do
  @moduledoc false

  alias Claptrap.Catalog.{Entry, Sink, Source, Subscription}

  def serialize(%Source{} = s) do
    %{
      id: s.id,
      type: s.type,
      name: s.name,
      config: s.config,
      enabled: s.enabled,
      tags: s.tags,
      last_consumed_at: s.last_consumed_at,
      inserted_at: s.inserted_at,
      updated_at: s.updated_at
    }
  end

  def serialize(%Sink{} = s) do
    %{
      id: s.id,
      type: s.type,
      name: s.name,
      config: s.config,
      enabled: s.enabled,
      inserted_at: s.inserted_at,
      updated_at: s.updated_at
    }
  end

  def serialize(%Entry{} = e) do
    %{
      id: e.id,
      external_id: e.external_id,
      title: e.title,
      summary: e.summary,
      url: e.url,
      author: e.author,
      published_at: e.published_at,
      status: e.status,
      metadata: e.metadata,
      tags: e.tags,
      source_id: e.source_id,
      inserted_at: e.inserted_at,
      updated_at: e.updated_at
    }
  end

  def serialize(%Subscription{} = s) do
    %{
      id: s.id,
      sink_id: s.sink_id,
      tags: s.tags,
      inserted_at: s.inserted_at,
      updated_at: s.updated_at
    }
  end
end
