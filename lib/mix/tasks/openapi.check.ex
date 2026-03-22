defmodule Mix.Tasks.Openapi.Check do
  @shortdoc "Verify committed OpenAPI spec matches code"
  @moduledoc """
  Regenerate the OpenAPI spec and verify it matches the committed version.

  Fails with a non-zero exit code if the spec has drifted from the
  code-defined schema, indicating that `mix openapi.export` needs to be
  run and the result committed.

  ## Examples

      $ mix openapi.check
  """

  use Mix.Task

  @spec_path Path.join("docs", Path.join("openapi", "v1.json"))

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("openapi.export")

    {output, exit_code} = System.cmd("git", ["diff", "--exit-code", @spec_path])

    if exit_code != 0 do
      Mix.shell().error("OpenAPI spec is out of date. Run `mix openapi.export` and commit.")
      Mix.shell().error(output)
      exit({:shutdown, 1})
    else
      Mix.shell().info("OpenAPI spec is up to date.")
    end
  end
end
