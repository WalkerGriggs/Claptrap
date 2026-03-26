defmodule Claptrap.API.Operations.Subscriptions do
  @moduledoc """
  OpenAPI definitions for subscription endpoints.
  
  The operations cover listing, creating, fetching, and deleting subscriptions,
  including pagination parameters for list calls and error/validation response
  contracts.
  """

  alias OpenApiSpex.{Operation, PathItem, Schema}

  alias Claptrap.API.Schemas.{
    CreateSubscriptionRequest,
    Error,
    Pagination,
    SubscriptionResponse,
    ValidationError
  }

  def paths do
    %{
      "/subscriptions" => %PathItem{
        get: list_subscriptions(),
        post: create_subscription()
      },
      "/subscriptions/{id}" => %PathItem{
        get: get_subscription(),
        delete: delete_subscription()
      }
    }
  end

  defp list_subscriptions do
    %Operation{
      tags: ["Subscriptions"],
      summary: "List subscriptions",
      operationId: "listSubscriptions",
      parameters: Pagination.page_parameters(),
      responses: %{
        200 =>
          Operation.response(
            "Paginated list of subscriptions",
            "application/json",
            Pagination.paginated_response(SubscriptionResponse.schema())
          )
      }
    }
  end

  defp create_subscription do
    %Operation{
      tags: ["Subscriptions"],
      summary: "Create a subscription",
      operationId: "createSubscription",
      requestBody:
        Operation.request_body(
          "Subscription to create",
          "application/json",
          CreateSubscriptionRequest,
          required: true
        ),
      responses: %{
        201 =>
          Operation.response(
            "Created subscription",
            "application/json",
            SubscriptionResponse
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
    Operation.parameter(:id, :path, %Schema{type: :string, format: :uuid}, "Subscription ID")
  end

  defp get_subscription do
    %Operation{
      tags: ["Subscriptions"],
      summary: "Get a subscription",
      operationId: "getSubscription",
      parameters: [id_parameter()],
      responses: %{
        200 =>
          Operation.response(
            "Subscription found",
            "application/json",
            SubscriptionResponse
          ),
        404 =>
          Operation.response(
            "Subscription not found",
            "application/json",
            Error
          )
      }
    }
  end

  defp delete_subscription do
    %Operation{
      tags: ["Subscriptions"],
      summary: "Delete a subscription",
      operationId: "deleteSubscription",
      parameters: [id_parameter()],
      responses: %{
        204 => %OpenApiSpex.Response{
          description: "Subscription deleted"
        },
        404 =>
          Operation.response(
            "Subscription not found",
            "application/json",
            Error
          )
      }
    }
  end
end
