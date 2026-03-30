defmodule Claptrap.API.Schemas.ArtifactResponse do
  @moduledoc """
  OpenAPI schema module for artifact response objects.

  The schema models normalized artifact payloads returned by the API, including
  entry identity, format, content payload fields, extractor name, and timestamps.
  """

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ArtifactResponse",
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      entry_id: %Schema{type: :string, format: :uuid},
      format: %Schema{
        type: :string,
        enum: ["markdown", "html", "pdf"]
      },
      content: %Schema{type: :string, nullable: true},
      content_type: %Schema{type: :string, nullable: true},
      byte_size: %Schema{type: :integer, nullable: true},
      extractor: %Schema{type: :string},
      metadata: %Schema{type: :object, nullable: true},
      inserted_at: %Schema{type: :string, format: :"date-time"},
      updated_at: %Schema{type: :string, format: :"date-time"}
    },
    required: [
      :id,
      :entry_id,
      :format,
      :extractor,
      :inserted_at,
      :updated_at
    ]
  })
end

defmodule Claptrap.API.Schemas.CreateArtifactRequest do
  @moduledoc """
  OpenAPI schema for artifact creation requests.

  This schema documents the request body accepted by `POST /artifacts` and
  requires `entry_id`, `format`, and `extractor`.
  """

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "CreateArtifactRequest",
    type: :object,
    properties: %{
      entry_id: %Schema{type: :string, format: :uuid},
      format: %Schema{
        type: :string,
        enum: ["markdown", "html", "pdf"]
      },
      extractor: %Schema{type: :string},
      content: %Schema{type: :string, nullable: true},
      content_type: %Schema{type: :string, nullable: true},
      byte_size: %Schema{type: :integer, nullable: true},
      metadata: %Schema{type: :object, nullable: true}
    },
    required: [:entry_id, :format, :extractor]
  })
end
