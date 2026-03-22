defmodule Claptrap.API.Schemas.ValidationError do
  @moduledoc false

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
