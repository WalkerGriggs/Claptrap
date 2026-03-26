defmodule Claptrap.API.Schemas.Error do
  @moduledoc """
  OpenAPI schema for basic error responses.
  
  This schema represents payloads with a single `error` message field.
  """

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Error",
    type: :object,
    properties: %{
      error: %Schema{type: :string, description: "Error message"}
    },
    required: [:error]
  })
end
