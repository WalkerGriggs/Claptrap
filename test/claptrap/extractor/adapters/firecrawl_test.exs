defmodule Claptrap.Extractor.Adapters.FirecrawlTest do
  use ExUnit.Case, async: false

  import Plug.Conn

  alias Claptrap.Extractor.Adapters.Firecrawl

  setup do
    Req.Test.set_req_test_to_shared()

    previous_options = Application.get_env(:claptrap, :firecrawl_req_options, [])
    Application.put_env(:claptrap, :firecrawl_req_options, plug: {Req.Test, Firecrawl})

    on_exit(fn ->
      Application.put_env(:claptrap, :firecrawl_req_options, previous_options)
    end)

    :ok
  end

  describe "supported_formats/0" do
    test "returns markdown and html" do
      assert Firecrawl.supported_formats() == ["markdown", "html"]
    end
  end

  describe "extract/3" do
    test "success with markdown format" do
      Req.Test.expect(Firecrawl, fn conn ->
        {:ok, body, conn} = read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["url"] == "https://example.com"
        assert decoded["formats"] == ["markdown"]

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          200,
          Jason.encode!(%{
            "success" => true,
            "data" => %{
              "markdown" => "# Hello World",
              "metadata" => %{"title" => "Hello"}
            }
          })
        )
      end)

      assert {:ok, result} = Firecrawl.extract("https://example.com", "markdown", %{})
      assert result.content == "# Hello World"
      assert result.content_type == "text/markdown"
      assert result.metadata == %{"title" => "Hello"}
    end

    test "success with html format" do
      Req.Test.expect(Firecrawl, fn conn ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          200,
          Jason.encode!(%{
            "success" => true,
            "data" => %{
              "html" => "<h1>Hello World</h1>",
              "metadata" => %{"title" => "Hello"}
            }
          })
        )
      end)

      assert {:ok, result} = Firecrawl.extract("https://example.com", "html", %{})
      assert result.content == "<h1>Hello World</h1>"
      assert result.content_type == "text/html"
    end

    test "rate limited (429)" do
      Req.Test.expect(Firecrawl, fn conn ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(429, Jason.encode!(%{"error" => "rate limited"}))
      end)

      assert {:error, %{status: 429}} = Firecrawl.extract("https://example.com", "markdown", %{})
    end

    test "server error (500)" do
      Req.Test.expect(Firecrawl, fn conn ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(500, Jason.encode!(%{"error" => "internal error"}))
      end)

      assert {:error, %{status: 500}} = Firecrawl.extract("https://example.com", "markdown", %{})
    end

    test "network timeout" do
      Req.Test.expect(Firecrawl, &Req.Test.transport_error(&1, :timeout))

      assert {:error, %Req.TransportError{reason: :timeout}} =
               Firecrawl.extract("https://example.com", "markdown", %{})
    end

    test "malformed response missing data fields" do
      Req.Test.expect(Firecrawl, fn conn ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{"success" => true, "data" => %{}}))
      end)

      assert {:error, %{reason: :missing_content}} =
               Firecrawl.extract("https://example.com", "markdown", %{})
    end
  end
end
