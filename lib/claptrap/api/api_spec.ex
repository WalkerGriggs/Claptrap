defmodule Claptrap.API.ApiSpec do
  @moduledoc false

  alias Claptrap.API.Operations
  alias OpenApiSpex.{Info, OpenApi, Server}

  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      info: %Info{
        title: "Claptrap",
        version: "0.1.0",
        description: "Content ingestion and delivery API"
      },
      servers: [%Server{url: "/api/v1"}],
      paths:
        Operations.Sources.paths()
        |> Map.merge(Operations.Subscriptions.paths())
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
