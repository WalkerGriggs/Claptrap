defmodule Claptrap.API.Auth do
  @moduledoc false

  @behaviour Plug

  import Plug.Conn

  @default_except ["/health", "/ready"]

  @impl Plug
  def init(opts) do
    %{except: Keyword.get(opts, :except, @default_except)}
  end

  @impl Plug
  def call(conn, %{except: except}) do
    if conn.request_path in except do
      conn
    else
      authenticate(conn)
    end
  end

  defp authenticate(conn) do
    with [header | _] <- get_req_header(conn, "authorization"),
         "Bearer " <> token <- header,
         true <- valid_token?(token) do
      conn
    else
      _ -> unauthorized(conn)
    end
  end

  defp valid_token?(token) do
    case Application.get_env(:claptrap, :api_key) do
      nil -> false
      key -> Plug.Crypto.secure_compare(token, key)
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{error: "unauthorized"}))
    |> halt()
  end
end
