defmodule Claptrap.API.Handlers.Subscriptions do
  @moduledoc false

  use Plug.Router

  alias Claptrap.Catalog
  import Claptrap.API.Helpers

  plug(:match)
  plug(:dispatch)

  get "/" do
    opts = filter_opts(conn.query_params)
    subscriptions = Catalog.list_subscriptions(opts)
    json(conn, 200, subscriptions)
  end

  post "/" do
    case Catalog.create_subscription(conn.body_params) do
      {:ok, subscription} -> json(conn, 201, subscription)
      {:error, changeset} -> json(conn, 422, %{errors: changeset_errors(changeset)})
    end
  end

  get "/:id" do
    subscription = Catalog.get_subscription!(id)
    json(conn, 200, subscription)
  end

  delete "/:id" do
    subscription = Catalog.get_subscription!(id)
    {:ok, _} = Catalog.delete_subscription(subscription)
    send_resp(conn, 204, "")
  end

  match _ do
    send_resp(conn, 404, Jason.encode!(%{error: "not found"}))
  end

  defp filter_opts(%{"sink_id" => sink_id}), do: [sink_id: sink_id]
  defp filter_opts(_), do: []
end
