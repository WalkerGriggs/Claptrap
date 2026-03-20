defmodule Claptrap.API.Handlers.Sources do
  @moduledoc false

  use Plug.Router

  alias Claptrap.Catalog
  import Claptrap.API.Helpers

  plug(:match)
  plug(:dispatch)

  get "/" do
    opts = filter_opts(conn.query_params)
    sources = Catalog.list_sources(opts)
    json(conn, 200, sources)
  end

  post "/" do
    case Catalog.create_source(conn.body_params) do
      {:ok, source} -> json(conn, 201, source)
      {:error, changeset} -> json(conn, 422, %{errors: changeset_errors(changeset)})
    end
  end

  get "/:id" do
    source = Catalog.get_source!(id)
    json(conn, 200, source)
  end

  patch "/:id" do
    source = Catalog.get_source!(id)

    case Catalog.update_source(source, conn.body_params) do
      {:ok, updated} -> json(conn, 200, updated)
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

  defp filter_opts(%{"enabled" => "true"}), do: [enabled: true]
  defp filter_opts(%{"enabled" => "false"}), do: [enabled: false]
  defp filter_opts(_), do: []
end
