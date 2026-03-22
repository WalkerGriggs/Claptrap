defmodule Claptrap.API.Schemas.SourceResponse do
  @moduledoc false

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "SourceResponse",
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      type: %Schema{type: :string},
      name: %Schema{type: :string},
      config: %Schema{type: :object},
      enabled: %Schema{type: :boolean},
      tags: %Schema{type: :array, items: %Schema{type: :string}},
      last_consumed_at: %Schema{type: :string, format: :"date-time", nullable: true},
      inserted_at: %Schema{type: :string, format: :"date-time"},
      updated_at: %Schema{type: :string, format: :"date-time"}
    },
    required: [:id, :type, :name, :config, :enabled, :last_consumed_at, :tags, :inserted_at, :updated_at]
  })
end

defmodule Claptrap.API.Schemas.CreateSourceRequest do
  @moduledoc false

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "CreateSourceRequest",
    type: :object,
    properties: %{
      type: %Schema{type: :string},
      name: %Schema{type: :string},
      config: %Schema{type: :object},
      credentials: %Schema{type: :object},
      enabled: %Schema{type: :boolean, default: true},
      tags: %Schema{type: :array, items: %Schema{type: :string}}
    },
    required: [:type, :name, :config]
  })
end

defmodule Claptrap.API.Schemas.UpdateSourceRequest do
  @moduledoc false

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "UpdateSourceRequest",
    type: :object,
    properties: %{
      type: %Schema{type: :string},
      name: %Schema{type: :string},
      config: %Schema{type: :object},
      credentials: %Schema{type: :object},
      enabled: %Schema{type: :boolean},
      tags: %Schema{type: :array, items: %Schema{type: :string}}
    }
  })
end
