defmodule Claptrap.Producer.Adapters.RssUriTest do
  use ExUnit.Case, async: true

  alias Claptrap.Producer.Adapters.RssUri

  describe "valid_with_scheme?/1" do
    test "accepts URLs with valid URI schemes" do
      valid_urls = [
        "https://example.com",
        "http://example.com/path?q=1",
        "ftp://example.com/resource",
        "foo+bar://example.com",
        "news:comp.lang.elixir"
      ]

      Enum.each(valid_urls, fn url ->
        assert RssUri.valid_with_scheme?(url), "expected valid scheme URL: #{url}"
      end)
    end

    test "rejects URLs missing or having invalid schemes" do
      invalid_urls = [
        "example.com/no-scheme",
        "/relative/path",
        "//example.com/no-scheme",
        "1http://example.com",
        "://example.com"
      ]

      Enum.each(invalid_urls, fn url ->
        refute RssUri.valid_with_scheme?(url), "expected invalid scheme URL: #{url}"
      end)
    end

    test "rejects non-binary values" do
      refute RssUri.valid_with_scheme?(nil)
      refute RssUri.valid_with_scheme?(123)
      refute RssUri.valid_with_scheme?(:https)
    end
  end
end
