defmodule Claptrap.API.Plug do
  @moduledoc """
  Top-level HTTP pipeline for Claptrap's API server.
  
  The pipeline logs requests, parses JSON bodies, sets JSON response content
  type, enforces authentication, and validates request bodies against the
  OpenAPI spec before dispatching to `Claptrap.API.Router`.
  
  Router execution is wrapped in rescue handling so common exception classes map
  to stable API errors: `Ecto.NoResultsError` to `404`, `Ecto.Query.CastError`
  to `400`, and all other errors to `500`.
  """

  use Plug.Builder

  alias Claptrap.API.{Auth, Router, ValidatePlug}

  plug(Plug.Logger)
  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
  plug(:put_json_content_type)
  plug(Auth)
  plug(ValidatePlug)
  plug(:handle_errors)

  defp put_json_content_type(conn, _opts) do
    put_resp_content_type(conn, "application/json")
  end

  defp handle_errors(conn, _opts) do
    Router.call(conn, Router.init([]))
  rescue
    error -> error_response(conn, error)
  end

  defp error_response(conn, %Plug.Conn.WrapperError{reason: reason}),
    do: error_response(conn, reason)

  defp error_response(conn, %Ecto.NoResultsError{}),
    do: send_resp(conn, 404, Jason.encode!(%{error: "not found"}))

  defp error_response(conn, %Ecto.Query.CastError{}),
    do: send_resp(conn, 400, Jason.encode!(%{error: "bad request"}))

  defp error_response(conn, _error),
    do: send_resp(conn, 500, Jason.encode!(%{error: "internal server error"}))
end
