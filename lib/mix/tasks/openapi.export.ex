defmodule Mix.Tasks.Openapi.Export do
  @shortdoc "Export OpenAPI spec to docs/openapi/v1.json"
  @moduledoc """
  Export the OpenAPI spec to `docs/openapi/v1.json`.

  The generated file can be committed to the repository and used for SDK
  generation, CI validation, and documentation tools.

  ## Examples

      $ mix openapi.export
  """

  use Mix.Task

  alias Claptrap.API.ApiSpec
  alias OpenApiSpex.OpenApi

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.config")

    spec = ApiSpec.spec()
    json = spec |> OpenApi.to_map() |> Jason.encode!(pretty: true)

    dir = Path.join("docs", "openapi")
    File.mkdir_p!(dir)
    file = Path.join(dir, "v1.json")
    File.write!(file, json <> "\n")

    Mix.shell().info("Wrote #{file}")
  end
end
