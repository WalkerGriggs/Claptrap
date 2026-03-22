defmodule Claptrap.API.Handlers.Entries do
  @moduledoc false

  use Plug.Router

  alias Claptrap.Catalog
  alias Claptrap.Pagination
  import Claptrap.API.Helpers

  plug(:match)
  plug(:dispatch)

  get "/" do
    opts = Pagination.params_to_opts(conn.query_params)
    page = Catalog.list_entries(opts)
    json(conn, 200, Pagination.to_response(page))
  end

  get "/:id" do
    entry = Catalog.get_entry!(id)
    json(conn, 200, entry)
  end

  patch "/:id" do
    entry = Catalog.get_entry!(id)

    case Catalog.update_entry(entry, conn.body_params) do
      {:ok, updated} -> json(conn, 200, updated)
      {:error, changeset} -> json(conn, 422, %{errors: changeset_errors(changeset)})
    end
  end

  match _ do
    send_resp(conn, 404, Jason.encode!(%{error: "not found"}))
  end
end
