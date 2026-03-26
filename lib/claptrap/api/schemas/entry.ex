defmodule Claptrap.API.Schemas.EntryResponse do
  @moduledoc """
  OpenAPI schema module for entry response objects.

  The schema models normalized entry payloads returned by the API, including
  source identity, status, optional metadata fields, tags, and timestamps.
  """

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "EntryResponse",
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      external_id: %Schema{type: :string},
      title: %Schema{type: :string},
      summary: %Schema{type: :string, nullable: true},
      url: %Schema{type: :string, nullable: true},
      author: %Schema{type: :string, nullable: true},
      published_at: %Schema{type: :string, format: :"date-time", nullable: true},
      status: %Schema{
        type: :string,
        enum: ["unread", "in_progress", "read", "archived"]
      },
      metadata: %Schema{type: :object, nullable: true},
      tags: %Schema{type: :array, items: %Schema{type: :string}},
      source_id: %Schema{type: :string, format: :uuid},
      inserted_at: %Schema{type: :string, format: :"date-time"},
      updated_at: %Schema{type: :string, format: :"date-time"}
    },
    required: [
      :id,
      :external_id,
      :title,
      :status,
      :tags,
      :source_id,
      :inserted_at,
      :updated_at
    ]
  })
end

defmodule Claptrap.API.Schemas.CreateEntryRequest do
  @moduledoc """
  OpenAPI schema for entry creation requests.

  This schema documents the request body accepted by `POST /entries` and
  requires `source_id`, `external_id`, `title`, and `status`.
  """

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "CreateEntryRequest",
    type: :object,
    properties: %{
      source_id: %Schema{type: :string, format: :uuid},
      external_id: %Schema{type: :string},
      title: %Schema{type: :string},
      summary: %Schema{type: :string, nullable: true},
      url: %Schema{type: :string, nullable: true},
      author: %Schema{type: :string, nullable: true},
      published_at: %Schema{
        type: :string,
        format: :"date-time",
        nullable: true
      },
      status: %Schema{
        type: :string,
        enum: ["unread", "in_progress", "read", "archived"]
      },
      metadata: %Schema{type: :object, nullable: true},
      tags: %Schema{
        type: :array,
        items: %Schema{type: :string}
      }
    },
    required: [:source_id, :external_id, :title, :status]
  })
end

defmodule Claptrap.API.Schemas.UpdateEntryRequest do
  @moduledoc """
  OpenAPI schema for entry update requests.

  This schema documents partial entry updates accepted by `PATCH /entries/{id}`.
  Only status and tags are declared in the request shape.
  """

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "UpdateEntryRequest",
    type: :object,
    properties: %{
      status: %Schema{
        type: :string,
        enum: ["unread", "in_progress", "read", "archived"]
      },
      tags: %Schema{type: :array, items: %Schema{type: :string}}
    }
  })
end
