defmodule Claptrap.API.Schemas.ValidationError do
  @moduledoc """
  OpenAPI schema for validation error responses.

  The schema models a map of field names to lists of human-readable validation
  messages.
  """

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ValidationError",
    type: :object,
    properties: %{
      errors: %Schema{
        type: :object,
        description: "Field-level validation errors",
        additionalProperties: %Schema{
          type: :array,
          items: %Schema{type: :string}
        }
      }
    },
    required: [:errors]
  })
end
