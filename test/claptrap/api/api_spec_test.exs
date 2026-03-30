defmodule Claptrap.API.ApiSpecTest do
  use ExUnit.Case, async: true

  alias Claptrap.API.ApiSpec
  alias OpenApiSpex.{OpenApi, Server}

  describe "spec/0" do
    test "returns an OpenApi struct" do
      assert %OpenApi{} = ApiSpec.spec()
    end

    test "configures the API server" do
      %OpenApi{servers: [server]} = ApiSpec.spec()

      assert %Server{url: "/api/v1"} = server
    end

    test "includes Sources paths" do
      %OpenApi{paths: paths} = ApiSpec.spec()

      assert Map.has_key?(paths, "/sources")
      assert Map.has_key?(paths, "/sources/{id}")
    end

    test "includes Subscriptions paths" do
      %OpenApi{paths: paths} = ApiSpec.spec()

      assert Map.has_key?(paths, "/subscriptions")
      assert Map.has_key?(paths, "/subscriptions/{id}")
    end

    test "includes Artifacts paths" do
      %OpenApi{paths: paths} = ApiSpec.spec()

      assert Map.has_key?(paths, "/artifacts")
      assert Map.has_key?(paths, "/artifacts/{id}")
    end
  end
end
