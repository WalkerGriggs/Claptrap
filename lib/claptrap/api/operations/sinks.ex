defmodule Claptrap.API.Operations.Sinks do
  @moduledoc """
  OpenAPI path and operation definitions for sink endpoints.

  This module declares documentation metadata for listing, creating, fetching,
  updating, and deleting sinks, including expected parameters, request bodies,
  and response schemas.
  """

  alias OpenApiSpex.{Operation, PathItem, Schema}

  alias Claptrap.API.Schemas.{
    CreateSinkRequest,
    Error,
    Pagination,
    SinkResponse,
    UpdateSinkRequest,
    ValidationError
  }

  def paths do
    %{
      "/sinks" => %PathItem{
        get: list_sinks(),
        post: create_sink()
      },
      "/sinks/{id}" => %PathItem{
        get: get_sink(),
        patch: update_sink(),
        delete: delete_sink()
      }
    }
  end

  defp list_sinks do
    %Operation{
      tags: ["Sinks"],
      summary: "List sinks",
      operationId: "listSinks",
      parameters: Pagination.page_parameters(),
      responses: %{
        200 =>
          Operation.response(
            "Paginated list of sinks",
            "application/json",
            Pagination.paginated_response(SinkResponse.schema())
          )
      }
    }
  end

  defp create_sink do
    %Operation{
      tags: ["Sinks"],
      summary: "Create a sink",
      operationId: "createSink",
      requestBody:
        Operation.request_body(
          "Sink to create",
          "application/json",
          CreateSinkRequest,
          required: true
        ),
      responses: %{
        201 =>
          Operation.response(
            "Created sink",
            "application/json",
            SinkResponse
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
    Operation.parameter(:id, :path, %Schema{type: :string, format: :uuid}, "Sink ID")
  end

  defp get_sink do
    %Operation{
      tags: ["Sinks"],
      summary: "Get a sink",
      operationId: "getSink",
      parameters: [id_parameter()],
      responses: %{
        200 =>
          Operation.response(
            "Sink found",
            "application/json",
            SinkResponse
          ),
        400 =>
          Operation.response(
            "Invalid ID format",
            "application/json",
            Error
          ),
        404 =>
          Operation.response(
            "Sink not found",
            "application/json",
            Error
          )
      }
    }
  end

  defp update_sink do
    %Operation{
      tags: ["Sinks"],
      summary: "Update a sink",
      operationId: "updateSink",
      parameters: [id_parameter()],
      requestBody:
        Operation.request_body(
          "Sink attributes to update",
          "application/json",
          UpdateSinkRequest,
          required: true
        ),
      responses: %{
        200 =>
          Operation.response(
            "Updated sink",
            "application/json",
            SinkResponse
          ),
        400 =>
          Operation.response(
            "Invalid ID format",
            "application/json",
            Error
          ),
        404 =>
          Operation.response(
            "Sink not found",
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

  defp delete_sink do
    %Operation{
      tags: ["Sinks"],
      summary: "Delete a sink",
      operationId: "deleteSink",
      parameters: [id_parameter()],
      responses: %{
        204 => %OpenApiSpex.Response{description: "Sink deleted"},
        400 =>
          Operation.response(
            "Invalid ID format",
            "application/json",
            Error
          ),
        404 =>
          Operation.response(
            "Sink not found",
            "application/json",
            Error
          )
      }
    }
  end
end
