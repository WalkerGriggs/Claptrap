defmodule Claptrap.API.Handlers.Entries do
  @moduledoc false

  use Plug.Router

  alias Claptrap.Catalog
  import Claptrap.API.Helpers

  plug(:match)
  plug(:dispatch)

  get "/" do
    opts = filter_opts(conn.query_params)
    entries = Catalog.list_entries(opts)
    json(conn, 200, entries)
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

  defp filter_opts(params) do
    [order: {:desc, :inserted_at}]
    |> maybe_add(:status, params["status"])
    |> maybe_add(:source_id, params["source_id"])
    |> maybe_add_limit(params["limit"])
  end

  defp maybe_add(opts, _key, nil), do: opts
  defp maybe_add(opts, key, value), do: Keyword.put(opts, key, value)

  defp maybe_add_limit(opts, nil), do: opts

  defp maybe_add_limit(opts, value) do
    case Integer.parse(value) do
      {int, ""} when int > 0 -> Keyword.put(opts, :limit, int)
      _ -> opts
    end
  end
end
