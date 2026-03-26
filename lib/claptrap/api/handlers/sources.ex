defmodule Claptrap.API.Handlers.Sources do
  @moduledoc """
  Router for `/api/v1/sources` resource endpoints.

  This handler provides CRUD operations for sources through `Claptrap.Catalog`.
  List responses use cursor pagination helpers and serialize items through
  `Claptrap.API.Serializers`.

  Validation failures from Ecto changesets are returned as `422` JSON payloads.
  """

  use Plug.Router

  alias Claptrap.API.Serializers
  alias Claptrap.Catalog
  alias Claptrap.Pagination
  import Claptrap.API.Helpers

  plug(:match)
  plug(:dispatch)

  get "/" do
    opts = Pagination.params_to_opts(conn.query_params)
    page = Catalog.list_sources(opts)
    response = Pagination.to_response(page)
    json(conn, 200, %{response | items: Enum.map(response.items, &Serializers.serialize/1)})
  end

  post "/" do
    case Catalog.create_source(conn.body_params) do
      {:ok, source} -> json(conn, 201, Serializers.serialize(source))
      {:error, changeset} -> json(conn, 422, %{errors: changeset_errors(changeset)})
    end
  end

  get "/:id" do
    source = Catalog.get_source!(id)
    json(conn, 200, Serializers.serialize(source))
  end

  patch "/:id" do
    source = Catalog.get_source!(id)

    case Catalog.update_source(source, conn.body_params) do
      {:ok, updated} -> json(conn, 200, Serializers.serialize(updated))
      {:error, changeset} -> json(conn, 422, %{errors: changeset_errors(changeset)})
    end
  end

  delete "/:id" do
    source = Catalog.get_source!(id)
    {:ok, _} = Catalog.delete_source(source)
    send_resp(conn, 204, "")
  end

  match _ do
    send_resp(conn, 404, Jason.encode!(%{error: "not found"}))
  end
end
