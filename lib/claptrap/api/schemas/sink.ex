defmodule Claptrap.API.Schemas.SinkResponse do
  @moduledoc """
  OpenAPI schema module for sink response objects.

  The schema models the JSON payload returned for sink resources, including
  identity, configuration, enabled state, and timestamps.
  """

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "SinkResponse",
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      type: %Schema{type: :string},
      name: %Schema{type: :string},
      config: %Schema{type: :object},
      enabled: %Schema{type: :boolean},
      inserted_at: %Schema{type: :string, format: :"date-time"},
      updated_at: %Schema{type: :string, format: :"date-time"}
    },
    required: [:id, :type, :name, :config, :enabled, :inserted_at, :updated_at]
  })
end

defmodule Claptrap.API.Schemas.CreateSinkRequest do
  @moduledoc """
  OpenAPI schema for sink creation requests.

  This schema documents the request body accepted by `POST /sinks` and marks
  `type`, `name`, and `config` as required fields.
  """

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "CreateSinkRequest",
    type: :object,
    properties: %{
      type: %Schema{type: :string},
      name: %Schema{type: :string},
      config: %Schema{type: :object},
      credentials: %Schema{type: :object},
      enabled: %Schema{type: :boolean, default: true}
    },
    required: [:type, :name, :config]
  })
end

defmodule Claptrap.API.Schemas.UpdateSinkRequest do
  @moduledoc """
  OpenAPI schema for sink update requests.

  This schema documents partial attributes accepted by `PATCH /sinks/{id}`.
  """

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "UpdateSinkRequest",
    type: :object,
    properties: %{
      type: %Schema{type: :string},
      name: %Schema{type: :string},
      config: %Schema{type: :object},
      credentials: %Schema{type: :object},
      enabled: %Schema{type: :boolean}
    }
  })
end
