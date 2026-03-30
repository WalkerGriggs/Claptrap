defmodule Claptrap.API.Handlers.Artifacts do
  @moduledoc """
  Router for `/api/v1/artifacts` resource endpoints.

  This handler supports listing, creating, fetching, and deleting artifacts
  through `Claptrap.Catalog`. List responses use pagination helpers and
  serialize artifact structs through `Claptrap.API.Serializers`.

  Validation failures from changesets are returned as `422` JSON payloads.
  """

  use Plug.Router

  alias Claptrap.API.Serializers
  alias Claptrap.Catalog
  alias Claptrap.Pagination
  import Claptrap.API.Helpers

  plug(:match)
  plug(:dispatch)

  get "/" do
    opts =
      Pagination.params_to_opts(conn.query_params)
      |> put_entry_id(conn.query_params["entry_id"])

    page = Catalog.list_artifacts(opts)
    response = Pagination.to_response(page)
    json(conn, 200, %{response | items: Enum.map(response.items, &Serializers.serialize/1)})
  end

  post "/" do
    case Catalog.create_artifact(conn.body_params) do
      {:ok, artifact} -> json(conn, 201, Serializers.serialize(artifact))
      {:error, changeset} -> json(conn, 422, %{errors: changeset_errors(changeset)})
    end
  end

  get "/:id" do
    artifact = Catalog.get_artifact!(id)
    json(conn, 200, Serializers.serialize(artifact))
  end

  delete "/:id" do
    artifact = Catalog.get_artifact!(id)
    {:ok, _} = Catalog.delete_artifact(artifact)
    send_resp(conn, 204, "")
  end

  match _ do
    send_resp(conn, 404, Jason.encode!(%{error: "not found"}))
  end

  defp put_entry_id(opts, nil), do: opts
  defp put_entry_id(opts, id), do: Keyword.put(opts, :entry_id, id)
end
