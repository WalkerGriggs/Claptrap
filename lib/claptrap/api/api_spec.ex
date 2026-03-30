defmodule Claptrap.API.ApiSpec do
  @moduledoc """
  OpenAPI document builder for the HTTP API.

  `spec/0` constructs the OpenAPI root object with metadata, server prefix, and
  merged path definitions from the resource operation modules. It then resolves
  schema module references with `OpenApiSpex.resolve_schema_modules/1`.
  """

  alias Claptrap.API.Operations
  alias OpenApiSpex.{Info, OpenApi, Server}

  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      info: %Info{
        title: "Claptrap",
        version: "0.2.0",
        description: "Content ingestion and delivery API"
      },
      servers: [%Server{url: "/api/v1"}],
      paths:
        Operations.Sources.paths()
        |> Map.merge(Operations.Subscriptions.paths())
        |> Map.merge(Operations.Entries.paths())
        |> Map.merge(Operations.Sinks.paths())
        |> Map.merge(Operations.Artifacts.paths())
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
