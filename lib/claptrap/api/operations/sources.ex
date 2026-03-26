defmodule Claptrap.API.Operations.Sources do
  @moduledoc """
  OpenAPI path and operation definitions for source endpoints.
  
  This module declares documentation metadata for listing, creating, fetching,
  updating, and deleting sources, including expected parameters, request bodies,
  and response schemas.
  """

  alias OpenApiSpex.{Operation, PathItem, Schema}

  alias Claptrap.API.Schemas.{
    CreateSourceRequest,
    Error,
    Pagination,
    SourceResponse,
    UpdateSourceRequest,
    ValidationError
  }

  def paths do
    %{
      "/sources" => %PathItem{
        get: list_sources(),
        post: create_source()
      },
      "/sources/{id}" => %PathItem{
        get: get_source(),
        patch: update_source(),
        delete: delete_source()
      }
    }
  end

  defp list_sources do
    %Operation{
      tags: ["Sources"],
      summary: "List sources",
      operationId: "listSources",
      parameters: Pagination.page_parameters(),
      responses: %{
        200 =>
          Operation.response(
            "Paginated list of sources",
            "application/json",
            Pagination.paginated_response(SourceResponse.schema())
          )
      }
    }
  end

  defp create_source do
    %Operation{
      tags: ["Sources"],
      summary: "Create a source",
      operationId: "createSource",
      requestBody:
        Operation.request_body(
          "Source to create",
          "application/json",
          CreateSourceRequest,
          required: true
        ),
      responses: %{
        201 =>
          Operation.response(
            "Created source",
            "application/json",
            SourceResponse
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
    Operation.parameter(:id, :path, %Schema{type: :string, format: :uuid}, "Source ID")
  end

  defp get_source do
    %Operation{
      tags: ["Sources"],
      summary: "Get a source",
      operationId: "getSource",
      parameters: [id_parameter()],
      responses: %{
        200 =>
          Operation.response(
            "Source found",
            "application/json",
            SourceResponse
          ),
        400 =>
          Operation.response(
            "Invalid ID format",
            "application/json",
            Error
          ),
        404 =>
          Operation.response(
            "Source not found",
            "application/json",
            Error
          )
      }
    }
  end

  defp update_source do
    %Operation{
      tags: ["Sources"],
      summary: "Update a source",
      operationId: "updateSource",
      parameters: [id_parameter()],
      requestBody:
        Operation.request_body(
          "Source attributes to update",
          "application/json",
          UpdateSourceRequest,
          required: true
        ),
      responses: %{
        200 =>
          Operation.response(
            "Updated source",
            "application/json",
            SourceResponse
          ),
        400 =>
          Operation.response(
            "Invalid ID format",
            "application/json",
            Error
          ),
        404 =>
          Operation.response(
            "Source not found",
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

  defp delete_source do
    %Operation{
      tags: ["Sources"],
      summary: "Delete a source",
      operationId: "deleteSource",
      parameters: [id_parameter()],
      responses: %{
        204 => %OpenApiSpex.Response{description: "Source deleted"},
        400 =>
          Operation.response(
            "Invalid ID format",
            "application/json",
            Error
          ),
        404 =>
          Operation.response(
            "Source not found",
            "application/json",
            Error
          )
      }
    }
  end
end
