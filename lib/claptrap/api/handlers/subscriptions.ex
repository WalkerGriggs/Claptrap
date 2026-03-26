defmodule Claptrap.API.Handlers.Subscriptions do
  @moduledoc """
  Router for `/api/v1/subscriptions` endpoints.
  
  This handler supports listing, creating, fetching, and deleting subscriptions
  through `Claptrap.Catalog`. List responses are paginated and item payloads are
  serialized through `Claptrap.API.Serializers`.
  
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
    opts = Pagination.params_to_opts(conn.query_params)
    page = Catalog.list_subscriptions(opts)
    response = Pagination.to_response(page)
    json(conn, 200, %{response | items: Enum.map(response.items, &Serializers.serialize/1)})
  end

  post "/" do
    case Catalog.create_subscription(conn.body_params) do
      {:ok, subscription} -> json(conn, 201, Serializers.serialize(subscription))
      {:error, changeset} -> json(conn, 422, %{errors: changeset_errors(changeset)})
    end
  end

  get "/:id" do
    subscription = Catalog.get_subscription!(id)
    json(conn, 200, Serializers.serialize(subscription))
  end

  delete "/:id" do
    subscription = Catalog.get_subscription!(id)
    {:ok, _} = Catalog.delete_subscription(subscription)
    send_resp(conn, 204, "")
  end

  match _ do
    send_resp(conn, 404, Jason.encode!(%{error: "not found"}))
  end
end
