defmodule Claptrap.API.ValidatePlug do
  @moduledoc """
  Plug that validates request bodies using the OpenAPI spec.
  
  For each request, this plug finds the matching OpenAPI operation by HTTP
  method and path template, resolves that operation's request body schema, and
  casts the incoming body with `OpenApiSpex.Cast`.
  
  If casting fails, it responds with `422` and a field-keyed error payload built
  from cast errors. If no operation matches, the operation has no request body,
  or casting succeeds, the connection is passed through unchanged.
  """

  @behaviour Plug

  alias Claptrap.API.ApiSpec
  alias OpenApiSpex.{Cast, Reference, RequestBody}

  @server_prefix "/api/v1"

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    spec = ApiSpec.spec()

    with {:ok, operation} <- find_operation(spec, conn),
         {:ok, request_body} <- resolve_request_body(operation, spec),
         {:ok, _cast_params} <- cast_body(request_body, conn, spec) do
      conn
    else
      {:error, errors} -> send_validation_error(conn, errors)
      _ -> conn
    end
  end

  defp find_operation(spec, conn) do
    method = method_atom(conn.method)

    Enum.find_value(spec.paths, :error, fn {path_pattern, path_item} ->
      path_matches?(conn.request_path, @server_prefix <> path_pattern) &&
        operation_for_method(path_item, method)
    end)
  end

  defp operation_for_method(path_item, method) do
    case Map.get(path_item, method) do
      nil -> nil
      operation -> {:ok, operation}
    end
  end

  defp resolve_request_body(%{requestBody: nil}, _spec), do: :error

  defp resolve_request_body(%{requestBody: %Reference{} = ref}, spec) do
    case Reference.resolve_request_body(ref, spec.components.requestBodies) do
      nil -> :error
      body -> {:ok, body}
    end
  end

  defp resolve_request_body(%{requestBody: %RequestBody{} = body}, _spec), do: {:ok, body}
  defp resolve_request_body(_, _spec), do: :error

  defp cast_body(%RequestBody{content: content}, conn, spec) do
    content_type =
      case Plug.Conn.get_req_header(conn, "content-type") do
        [ct | _] -> ct |> String.split(";") |> hd() |> String.trim()
        _ -> "application/json"
      end

    case content do
      %{^content_type => media_type} ->
        Cast.cast(media_type.schema, conn.body_params, spec.components.schemas)

      _ ->
        supported = content |> Map.keys() |> Enum.join(", ")

        {:error,
         [
           %Cast.Error{
             reason: :invalid_type,
             name: "content-type",
             path: [],
             value: content_type,
             type: supported,
             format: nil,
             length: 0,
             meta: %{}
           }
         ]}
    end
  end

  defp path_matches?(request_path, pattern) do
    request_segments = String.split(request_path, "/", trim: true)
    pattern_segments = String.split(pattern, "/", trim: true)

    length(request_segments) == length(pattern_segments) &&
      Enum.zip(request_segments, pattern_segments)
      |> Enum.all?(fn
        {_, "{" <> _} -> true
        {a, b} -> a == b
      end)
  end

  defp method_atom("GET"), do: :get
  defp method_atom("POST"), do: :post
  defp method_atom("PUT"), do: :put
  defp method_atom("PATCH"), do: :patch
  defp method_atom("DELETE"), do: :delete
  defp method_atom(_), do: :unknown

  defp send_validation_error(conn, errors) do
    error_map = format_errors(errors)

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(422, Jason.encode!(%{errors: error_map}))
    |> Plug.Conn.halt()
  end

  defp format_errors(errors) do
    Enum.reduce(errors, %{}, fn error, acc ->
      {field, message} = extract_field_and_message(error)
      Map.update(acc, field, [message], &(&1 ++ [message]))
    end)
  end

  defp extract_field_and_message(%Cast.Error{path: path, name: name} = error) do
    field =
      case path do
        [] -> name || "base"
        parts -> parts |> List.last() |> to_string()
      end

    {field, Cast.Error.message(error)}
  end
end
