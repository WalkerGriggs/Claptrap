defmodule Claptrap.API.Router do
  @moduledoc """
  Root router for health checks and versioned API forwarding.
  
  This router serves process and dependency probes (`/health`, `/ready`),
  exposes the generated OpenAPI document at `/api/v1/openapi`, and forwards
  resource routes under `/api/v1/*` to dedicated handler routers.
  
  Readiness is database-backed. `/ready` returns `200` only when `SELECT 1`
  succeeds against the configured repository, otherwise it returns `503`.
  """

  use Plug.Router

  alias Claptrap.API.ApiSpec
  alias Claptrap.Repo
  alias Ecto.Adapters.SQL

  plug(:match)
  plug(:dispatch)

  get "/health" do
    send_resp(conn, 200, Jason.encode!(%{status: "ok"}))
  end

  get "/ready" do
    case SQL.query(Repo, "SELECT 1") do
      {:ok, _} ->
        send_resp(conn, 200, Jason.encode!(%{status: "ready"}))

      {:error, _} ->
        send_resp(conn, 503, Jason.encode!(%{status: "unavailable"}))
    end
  end

  get "/api/v1/openapi" do
    spec = ApiSpec.spec() |> OpenApiSpex.OpenApi.to_map()
    send_resp(conn, 200, Jason.encode!(spec))
  end

  forward("/api/v1/sources", to: Claptrap.API.Handlers.Sources)
  forward("/api/v1/sinks", to: Claptrap.API.Handlers.Sinks)
  forward("/api/v1/subscriptions", to: Claptrap.API.Handlers.Subscriptions)
  forward("/api/v1/entries", to: Claptrap.API.Handlers.Entries)

  match _ do
    send_resp(conn, 404, Jason.encode!(%{error: "not found"}))
  end
end
