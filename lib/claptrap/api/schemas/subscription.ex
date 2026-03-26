defmodule Claptrap.API.Schemas.SubscriptionResponse do
  @moduledoc """
  OpenAPI schema module for subscription responses.

  The schema models subscription payloads returned by the API, including sink
  association, matching tags, and timestamps.
  """

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "SubscriptionResponse",
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      sink_id: %Schema{type: :string, format: :uuid},
      tags: %Schema{type: :array, items: %Schema{type: :string}},
      inserted_at: %Schema{type: :string, format: :"date-time"},
      updated_at: %Schema{type: :string, format: :"date-time"}
    },
    required: [:id, :sink_id, :tags, :inserted_at, :updated_at]
  })
end

defmodule Claptrap.API.Schemas.CreateSubscriptionRequest do
  @moduledoc """
  OpenAPI schema for subscription creation requests.

  This schema documents the request body accepted by `POST /subscriptions` and
  requires a sink identifier.
  """

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "CreateSubscriptionRequest",
    type: :object,
    properties: %{
      sink_id: %Schema{type: :string, format: :uuid},
      tags: %Schema{type: :array, items: %Schema{type: :string}, default: []}
    },
    required: [:sink_id]
  })
end
