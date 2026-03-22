defmodule Claptrap.API.Handlers.Sinks do
  @moduledoc false

  use Plug.Router

  alias Claptrap.Catalog
  alias Claptrap.Pagination
  import Claptrap.API.Helpers

  plug(:match)
  plug(:dispatch)

  get "/" do
    opts = Pagination.params_to_opts(conn.query_params)
    page = Catalog.list_sinks(opts)
    json(conn, 200, Pagination.to_response(page))
  end

  post "/" do
    case Catalog.create_sink(conn.body_params) do
      {:ok, sink} -> json(conn, 201, sink)
      {:error, changeset} -> json(conn, 422, %{errors: changeset_errors(changeset)})
    end
  end

  get "/:id" do
    sink = Catalog.get_sink!(id)
    json(conn, 200, sink)
  end

  patch "/:id" do
    sink = Catalog.get_sink!(id)

    case Catalog.update_sink(sink, conn.body_params) do
      {:ok, updated} -> json(conn, 200, updated)
      {:error, changeset} -> json(conn, 422, %{errors: changeset_errors(changeset)})
    end
  end

  delete "/:id" do
    sink = Catalog.get_sink!(id)
    {:ok, _} = Catalog.delete_sink(sink)
    send_resp(conn, 204, "")
  end

  match _ do
    send_resp(conn, 404, Jason.encode!(%{error: "not found"}))
  end
end
