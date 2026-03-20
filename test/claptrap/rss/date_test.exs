defmodule Claptrap.RSS.DateTest do
  use ExUnit.Case, async: true

  alias Claptrap.RSS.Date, as: RSSDate

  describe "parse/1 — RFC 822 with named timezone" do
    test "GMT" do
      assert {:ok, dt} = RSSDate.parse("Thu, 04 Oct 2007 23:59:45 GMT")
      assert dt == ~U[2007-10-04 23:59:45Z]
    end

    test "UTC" do
      assert {:ok, dt} = RSSDate.parse("Thu, 04 Oct 2007 23:59:45 UTC")
      assert dt == ~U[2007-10-04 23:59:45Z]
    end

    test "UT" do
      assert {:ok, dt} = RSSDate.parse("Thu, 04 Oct 2007 23:59:45 UT")
      assert dt == ~U[2007-10-04 23:59:45Z]
    end
  end

  describe "parse/1 — RFC 822 with numeric offset" do
    test "+0000" do
      assert {:ok, dt} = RSSDate.parse("Thu, 04 Oct 2007 23:59:45 +0000")
      assert dt == ~U[2007-10-04 23:59:45Z]
    end

    test "-0500" do
      assert {:ok, dt} = RSSDate.parse("Thu, 04 Oct 2007 18:59:45 -0500")
      assert dt == ~U[2007-10-04 23:59:45Z]
    end

    test "+0530" do
      assert {:ok, dt} = RSSDate.parse("Fri, 05 Oct 2007 05:29:45 +0530")
      assert dt == ~U[2007-10-04 23:59:45Z]
    end
  end

  describe "parse/1 — without day-of-week" do
    test "parses date without day-of-week prefix" do
      assert {:ok, dt} = RSSDate.parse("04 Oct 2007 23:59:45 GMT")
      assert dt == ~U[2007-10-04 23:59:45Z]
    end
  end

  describe "parse/1 — two-digit year" do
    test "year < 70 interpreted as 2000s" do
      assert {:ok, dt} = RSSDate.parse("04 Oct 07 23:59:45 GMT")
      assert dt.year == 2007
    end

    test "year >= 70 interpreted as 1900s" do
      assert {:ok, dt} = RSSDate.parse("04 Oct 99 23:59:45 GMT")
      assert dt.year == 1999
    end

    test "year == 69 interpreted as 2069" do
      assert {:ok, dt} = RSSDate.parse("04 Oct 69 23:59:45 GMT")
      assert dt.year == 2069
    end

    test "year == 70 interpreted as 1970" do
      assert {:ok, dt} = RSSDate.parse("01 Jan 70 00:00:00 GMT")
      assert dt.year == 1970
    end
  end

  describe "parse/1 — ISO 8601" do
    test "basic ISO 8601 with Z" do
      assert {:ok, dt} = RSSDate.parse("2007-10-04T23:59:45Z")
      assert dt == ~U[2007-10-04 23:59:45Z]
    end

    test "ISO 8601 with fractional seconds" do
      assert {:ok, dt} = RSSDate.parse("2007-10-04T23:59:45.123Z")
      assert dt.year == 2007
      assert dt.second == 45
    end

    test "ISO 8601 with offset" do
      assert {:ok, dt} = RSSDate.parse("2007-10-04T18:59:45-05:00")
      assert dt == ~U[2007-10-04 23:59:45Z]
    end
  end

  describe "parse/1 — full month name" do
    test "parses full month name format" do
      assert {:ok, dt} = RSSDate.parse("October 4, 2007")
      assert dt == ~U[2007-10-04 00:00:00Z]
    end

    test "parses with leading zero day" do
      assert {:ok, dt} = RSSDate.parse("October 04, 2007")
      assert dt == ~U[2007-10-04 00:00:00Z]
    end

    test "parses January" do
      assert {:ok, dt} = RSSDate.parse("January 15, 2020")
      assert dt == ~U[2020-01-15 00:00:00Z]
    end
  end

  describe "parse/1 — unix timestamp" do
    test "parses unix timestamp string" do
      assert {:ok, dt} = RSSDate.parse("1191542385")
      assert dt == DateTime.from_unix!(1_191_542_385)
    end
  end

  describe "parse/1 — wrong day-of-week" do
    test "ignores day-of-week mismatch" do
      # 2007-10-04 is a Thursday, but we say Tuesday
      assert {:ok, dt} = RSSDate.parse("Tue, 04 Oct 2007 23:59:45 GMT")
      assert dt == ~U[2007-10-04 23:59:45Z]
    end
  end

  describe "parse/1 — unknown timezone abbreviation" do
    test "treats unknown timezone as UTC" do
      assert {:ok, dt} = RSSDate.parse("Thu, 04 Oct 2007 23:59:45 CEST")
      assert dt == ~U[2007-10-04 23:59:45Z]
    end

    test "military timezone letters treated as UTC" do
      assert {:ok, dt} = RSSDate.parse("Thu, 04 Oct 2007 23:59:45 A")
      assert dt == ~U[2007-10-04 23:59:45Z]
    end
  end

  describe "parse/1 — whitespace handling" do
    test "strips leading whitespace" do
      assert {:ok, dt} = RSSDate.parse("  Thu, 04 Oct 2007 23:59:45 GMT")
      assert dt == ~U[2007-10-04 23:59:45Z]
    end

    test "strips trailing whitespace" do
      assert {:ok, dt} = RSSDate.parse("Thu, 04 Oct 2007 23:59:45 GMT   ")
      assert dt == ~U[2007-10-04 23:59:45Z]
    end

    test "strips both leading and trailing whitespace" do
      assert {:ok, dt} = RSSDate.parse("  Thu, 04 Oct 2007 23:59:45 GMT  ")
      assert dt == ~U[2007-10-04 23:59:45Z]
    end
  end

  describe "parse/1 — invalid inputs" do
    test "completely invalid input returns error" do
      assert {:error, :invalid_date} = RSSDate.parse("not a date at all")
    end

    test "empty string returns error" do
      assert {:error, :invalid_date} = RSSDate.parse("")
    end

    test "binary garbage returns error" do
      assert {:error, :invalid_date} = RSSDate.parse(<<0xFF, 0xFE, 0x00>>)
    end

    test "nil returns error" do
      assert {:error, :invalid_date} = RSSDate.parse(nil)
    end
  end

  describe "format/1" do
    test "produces correct day-of-week" do
      dt = ~U[2007-10-04 23:59:45Z]
      assert RSSDate.format(dt) == "Thu, 04 Oct 2007 23:59:45 +0000"
    end

    test "always uses 4-digit year" do
      dt = ~U[2007-10-04 23:59:45Z]
      formatted = RSSDate.format(dt)
      assert formatted =~ "2007"
    end

    test "always uses numeric offset" do
      dt = ~U[2007-10-04 23:59:45Z]
      formatted = RSSDate.format(dt)
      assert formatted =~ "+0000"
      refute formatted =~ "GMT"
      refute formatted =~ "UTC"
    end

    test "leading zero on single-digit day" do
      dt = ~U[2007-10-04 23:59:45Z]
      formatted = RSSDate.format(dt)
      assert formatted =~ "04 Oct"
    end

    test "correct month abbreviation for all 12 months" do
      months = ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

      for {abbrev, idx} <- Enum.with_index(months, 1) do
        dt = %DateTime{
          year: 2020,
          month: idx,
          day: 15,
          hour: 12,
          minute: 0,
          second: 0,
          time_zone: "Etc/UTC",
          zone_abbr: "UTC",
          utc_offset: 0,
          std_offset: 0,
          microsecond: {0, 0}
        }

        formatted = RSSDate.format(dt)
        assert formatted =~ abbrev, "Expected #{abbrev} in #{formatted}"
      end
    end

    test "day-of-week abbreviations are correct" do
      # 2020-01-06 is a Monday
      base = ~U[2020-01-06 12:00:00Z]
      expected_days = ~w(Mon Tue Wed Thu Fri Sat Sun)

      for {day_abbrev, offset} <- Enum.with_index(expected_days) do
        dt = DateTime.add(base, offset * 86_400, :second)
        formatted = RSSDate.format(dt)
        assert String.starts_with?(formatted, day_abbrev), "Expected #{day_abbrev} for #{formatted}"
      end
    end
  end

  describe "roundtrip" do
    test "parse(format(datetime)) returns the same datetime normalized to UTC" do
      dt = ~U[2007-10-04 23:59:45Z]
      assert {:ok, ^dt} = RSSDate.parse(RSSDate.format(dt))
    end

    test "roundtrip with midnight" do
      dt = ~U[2020-01-01 00:00:00Z]
      assert {:ok, ^dt} = RSSDate.parse(RSSDate.format(dt))
    end

    test "roundtrip with end of year" do
      dt = ~U[2023-12-31 23:59:59Z]
      assert {:ok, ^dt} = RSSDate.parse(RSSDate.format(dt))
    end
  end
end
