defmodule Claptrap.API.Handlers.Entries do
  @moduledoc false

  use Plug.Router

  alias Claptrap.API.Serializers
  alias Claptrap.Catalog
  alias Claptrap.Pagination
  import Claptrap.API.Helpers

  plug(:match)
  plug(:dispatch)

  get "/" do
    opts = Pagination.params_to_opts(conn.query_params)
    page = Catalog.list_entries(opts)
    response = Pagination.to_response(page)
    json(conn, 200, %{response | items: Enum.map(response.items, &Serializers.serialize/1)})
  end

  post "/" do
    case Catalog.create_entry(conn.body_params) do
      {:ok, entry} -> json(conn, 201, Serializers.serialize(entry))
      {:error, changeset} -> json(conn, 422, %{errors: changeset_errors(changeset)})
    end
  end

  get "/:id" do
    entry = Catalog.get_entry!(id)
    json(conn, 200, Serializers.serialize(entry))
  end

  patch "/:id" do
    entry = Catalog.get_entry!(id)

    case Catalog.update_entry(entry, conn.body_params) do
      {:ok, updated} -> json(conn, 200, Serializers.serialize(updated))
      {:error, changeset} -> json(conn, 422, %{errors: changeset_errors(changeset)})
    end
  end

  match _ do
    send_resp(conn, 404, Jason.encode!(%{error: "not found"}))
  end
end
