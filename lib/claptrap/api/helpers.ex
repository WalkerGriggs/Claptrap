defmodule Claptrap.API.Helpers do
  @moduledoc """
  Shared helpers for API handlers.

  `json/3` sends JSON responses with a provided status code, and
  `changeset_errors/1` turns Ecto changeset errors into a field-keyed map of
  human-readable messages.
  """

  import Plug.Conn

  def json(conn, status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(data))
  end

  def changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
