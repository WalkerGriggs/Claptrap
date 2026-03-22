defmodule Claptrap.API.Schemas.SinkResponse do
  @moduledoc false

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "SinkResponse",
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      type: %Schema{type: :string},
      name: %Schema{type: :string},
      config: %Schema{type: :object},
      enabled: %Schema{type: :boolean},
      inserted_at: %Schema{type: :string, format: :"date-time"},
      updated_at: %Schema{type: :string, format: :"date-time"}
    },
    required: [:id, :type, :name, :config, :enabled, :inserted_at, :updated_at]
  })
end

defmodule Claptrap.API.Schemas.CreateSinkRequest do
  @moduledoc false

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "CreateSinkRequest",
    type: :object,
    properties: %{
      type: %Schema{type: :string},
      name: %Schema{type: :string},
      config: %Schema{type: :object},
      credentials: %Schema{type: :object},
      enabled: %Schema{type: :boolean, default: true}
    },
    required: [:type, :name, :config]
  })
end

defmodule Claptrap.API.Schemas.UpdateSinkRequest do
  @moduledoc false

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "UpdateSinkRequest",
    type: :object,
    properties: %{
      type: %Schema{type: :string},
      name: %Schema{type: :string},
      config: %Schema{type: :object},
      credentials: %Schema{type: :object},
      enabled: %Schema{type: :boolean}
    }
  })
end
