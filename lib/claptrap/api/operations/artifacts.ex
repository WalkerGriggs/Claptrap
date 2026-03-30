defmodule Claptrap.API.Operations.Artifacts do
  @moduledoc """
  OpenAPI definitions for artifact endpoints.

  The operations cover listing, creating, fetching, and deleting artifacts,
  including pagination parameters for list calls, an optional entry filter,
  and validation or lookup errors for write and read paths.
  """

  alias OpenApiSpex.{Operation, PathItem, Schema}

  alias Claptrap.API.Schemas.{
    ArtifactResponse,
    CreateArtifactRequest,
    Error,
    Pagination,
    ValidationError
  }

  def paths do
    %{
      "/artifacts" => %PathItem{
        get: list_artifacts(),
        post: create_artifact()
      },
      "/artifacts/{id}" => %PathItem{
        get: get_artifact(),
        delete: delete_artifact()
      }
    }
  end

  defp list_artifacts do
    %Operation{
      tags: ["Artifacts"],
      summary: "List artifacts",
      operationId: "listArtifacts",
      parameters:
        Pagination.page_parameters() ++
          [
            Operation.parameter(
              :entry_id,
              :query,
              %Schema{type: :string, format: :uuid},
              "Filter by entry ID"
            )
          ],
      responses: %{
        200 =>
          Operation.response(
            "Paginated list of artifacts",
            "application/json",
            Pagination.paginated_response(ArtifactResponse.schema())
          )
      }
    }
  end

  defp create_artifact do
    %Operation{
      tags: ["Artifacts"],
      summary: "Create an artifact",
      operationId: "createArtifact",
      requestBody:
        Operation.request_body(
          "Artifact to create",
          "application/json",
          CreateArtifactRequest,
          required: true
        ),
      responses: %{
        201 =>
          Operation.response(
            "Created artifact",
            "application/json",
            ArtifactResponse
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
    Operation.parameter(:id, :path, %Schema{type: :string, format: :uuid}, "Artifact ID")
  end

  defp get_artifact do
    %Operation{
      tags: ["Artifacts"],
      summary: "Get an artifact",
      operationId: "getArtifact",
      parameters: [id_parameter()],
      responses: %{
        200 =>
          Operation.response(
            "Artifact found",
            "application/json",
            ArtifactResponse
          ),
        400 =>
          Operation.response(
            "Invalid ID format",
            "application/json",
            Error
          ),
        404 =>
          Operation.response(
            "Artifact not found",
            "application/json",
            Error
          )
      }
    }
  end

  defp delete_artifact do
    %Operation{
      tags: ["Artifacts"],
      summary: "Delete an artifact",
      operationId: "deleteArtifact",
      parameters: [id_parameter()],
      responses: %{
        204 =>
          Operation.response(
            "Artifact deleted",
            nil,
            nil
          ),
        400 =>
          Operation.response(
            "Invalid ID format",
            "application/json",
            Error
          ),
        404 =>
          Operation.response(
            "Artifact not found",
            "application/json",
            Error
          )
      }
    }
  end
end
