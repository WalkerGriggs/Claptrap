defmodule Claptrap.API.Schemas.Pagination do
  @moduledoc """
  Reusable OpenAPI schema helpers for cursor pagination.

  `page_parameters/0` defines query parameters used by list endpoints, and
  `paginated_response/1` builds a standard envelope with `items` and optional
  `next_page_token`.
  """

  alias OpenApiSpex.{Operation, Schema}

  def page_parameters do
    [
      Operation.parameter(
        :page_size,
        :query,
        %Schema{type: :integer, minimum: 1, maximum: 100, default: 25},
        "Number of items per page"
      ),
      Operation.parameter(
        :page_token,
        :query,
        %Schema{type: :string},
        "Cursor token for next page"
      )
    ]
  end

  def paginated_response(item_schema) do
    %Schema{
      type: :object,
      properties: %{
        items: %Schema{type: :array, items: item_schema},
        next_page_token: %Schema{
          type: :string,
          description: "Cursor for next page; absent on last page"
        }
      },
      required: [:items]
    }
  end
end
