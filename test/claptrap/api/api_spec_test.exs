defmodule Claptrap.API.ApiSpecTest do
  use ExUnit.Case, async: true

  alias Claptrap.API.ApiSpec
  alias OpenApiSpex.{Info, OpenApi, Server}

  describe "spec/0" do
    test "returns an OpenApi struct" do
      assert %OpenApi{} = ApiSpec.spec()
    end

    test "configures the API server" do
      %OpenApi{servers: [server]} = ApiSpec.spec()

      assert %Server{url: "/api/v1"} = server
    end

    test "paths is an empty map" do
      %OpenApi{paths: paths} = ApiSpec.spec()

      assert paths == %{}
    end
  end
end
