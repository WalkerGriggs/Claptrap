defmodule Claptrap.API.Operations.Entries do
  @moduledoc """
  OpenAPI definitions for entry endpoints.

  The operations cover listing, creating, fetching, and updating entries,
  including pagination parameters for list calls and validation or lookup errors
  for write and read paths.
  """

  alias OpenApiSpex.{Operation, PathItem, Schema}

  alias Claptrap.API.Schemas.{
    CreateEntryRequest,
    EntryResponse,
    Error,
    Pagination,
    UpdateEntryRequest,
    ValidationError
  }

  def paths do
    %{
      "/entries" => %PathItem{
        get: list_entries(),
        post: create_entry()
      },
      "/entries/{id}" => %PathItem{
        get: get_entry(),
        patch: update_entry()
      }
    }
  end

  defp list_entries do
    %Operation{
      tags: ["Entries"],
      summary: "List entries",
      operationId: "listEntries",
      parameters: Pagination.page_parameters(),
      responses: %{
        200 =>
          Operation.response(
            "Paginated list of entries",
            "application/json",
            Pagination.paginated_response(EntryResponse.schema())
          )
      }
    }
  end

  defp create_entry do
    %Operation{
      tags: ["Entries"],
      summary: "Create an entry",
      operationId: "createEntry",
      requestBody:
        Operation.request_body(
          "Entry to create",
          "application/json",
          CreateEntryRequest,
          required: true
        ),
      responses: %{
        201 =>
          Operation.response(
            "Created entry",
            "application/json",
            EntryResponse
          ),
        422 =>
          Operation.response(
            "Validation error",
            "application/json",
            ValidationError
          )
      }
    }
  end

  defp id_parameter do
    Operation.parameter(:id, :path, %Schema{type: :string, format: :uuid}, "Entry ID")
  end

  defp get_entry do
    %Operation{
      tags: ["Entries"],
      summary: "Get an entry",
      operationId: "getEntry",
      parameters: [id_parameter()],
      responses: %{
        200 =>
          Operation.response(
            "Entry found",
            "application/json",
            EntryResponse
          ),
        400 =>
          Operation.response(
            "Invalid ID format",
            "application/json",
            Error
          ),
        404 =>
          Operation.response(
            "Entry not found",
            "application/json",
            Error
          )
      }
    }
  end

  defp update_entry do
    %Operation{
      tags: ["Entries"],
      summary: "Update an entry",
      operationId: "updateEntry",
      parameters: [id_parameter()],
      requestBody:
        Operation.request_body(
          "Entry attributes to update",
          "application/json",
          UpdateEntryRequest,
          required: true
        ),
      responses: %{
        200 =>
          Operation.response(
            "Updated entry",
            "application/json",
            EntryResponse
          ),
        400 =>
          Operation.response(
            "Invalid ID format",
            "application/json",
            Error
          ),
        404 =>
          Operation.response(
            "Entry not found",
            "application/json",
            Error
          ),
        422 =>
          Operation.response(
            "Validation error",
            "application/json",
            ValidationError
          )
      }
    }
  end
end
