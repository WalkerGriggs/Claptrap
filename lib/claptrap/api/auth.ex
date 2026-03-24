defmodule Claptrap.API.Auth do
  @moduledoc false

  @behaviour Plug

  import Plug.Conn

  @default_except ["/health", "/ready"]

  @impl Plug
  def init(opts) do
    %{
      except: Keyword.get(opts, :except, @default_except),
      api_key: Keyword.get(opts, :api_key)
    }
  end

  @impl Plug
  def call(conn, %{except: except} = opts) do
    if conn.request_path in except do
      conn
    else
      authenticate(conn, opts)
    end
  end

  defp authenticate(conn, opts) do
    with [header | _] <- get_req_header(conn, "authorization"),
         "Bearer " <> token <- header,
         true <- valid_token?(token, opts) do
      conn
    else
      _ -> unauthorized(conn)
    end
  end

  defp valid_token?(token, opts) do
    key = opts[:api_key] || Application.get_env(:claptrap, :api_key)

    case key do
      k when is_binary(k) and byte_size(k) > 0 ->
        Plug.Crypto.secure_compare(token, k)

      _ ->
        false
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{error: "unauthorized"}))
    |> halt()
  end
end
