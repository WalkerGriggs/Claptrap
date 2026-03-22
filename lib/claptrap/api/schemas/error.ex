defmodule Claptrap.API.Schemas.Error do
  @moduledoc false

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
