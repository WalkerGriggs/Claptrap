defmodule Claptrap.RSS.Date do
  @moduledoc false

  @behaviour Claptrap.RSS.DateBehaviour

  @month_abbrevs ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
  @day_abbrevs ~w(Mon Tue Wed Thu Fri Sat Sun)

  @month_map @month_abbrevs
             |> Enum.with_index(1)
             |> Map.new(fn {name, idx} -> {String.downcase(name), idx} end)

  @full_month_map %{
    "january" => 1,
    "february" => 2,
    "march" => 3,
    "april" => 4,
    "may" => 5,
    "june" => 6,
    "july" => 7,
    "august" => 8,
    "september" => 9,
    "october" => 10,
    "november" => 11,
    "december" => 12
  }

  @named_tz_offsets %{
    "UTC" => 0,
    "GMT" => 0,
    "UT" => 0,
    "EDT" => -4 * 3600,
    "EST" => -5 * 3600,
    "CDT" => -5 * 3600,
    "CST" => -6 * 3600,
    "MDT" => -6 * 3600,
    "MST" => -7 * 3600,
    "PDT" => -7 * 3600,
    "PST" => -8 * 3600
  }

  @impl true
  @spec parse(binary()) :: {:ok, DateTime.t()} | {:error, :invalid_date}
  def parse(date_string) when is_binary(date_string) do
    date_string
    |> String.trim()
    |> try_parsers()
  end

  def parse(_), do: {:error, :invalid_date}

  @impl true
  @spec format(DateTime.t()) :: binary()
  def format(%DateTime{} = dt) do
    utc = DateTime.shift_zone!(dt, "Etc/UTC")
    dow = Enum.at(@day_abbrevs, Date.day_of_week(utc) - 1)
    month = Enum.at(@month_abbrevs, utc.month - 1)
    day = String.pad_leading(Integer.to_string(utc.day), 2, "0")

    "#{dow}, #{day} #{month} #{utc.year} " <>
      "#{pad2(utc.hour)}:#{pad2(utc.minute)}:#{pad2(utc.second)} +0000"
  end

  defp pad2(n), do: String.pad_leading(Integer.to_string(n), 2, "0")

  defp try_parsers(""), do: {:error, :invalid_date}

  defp try_parsers(s) do
    with {:error, _} <- parse_rfc822(s),
         {:error, _} <- parse_iso8601(s),
         {:error, _} <- parse_full_month(s),
         {:error, _} <- parse_unix_timestamp(s) do
      {:error, :invalid_date}
    end
  end

  # RFC 822: optional "Day, " then "DD Mon YYYY HH:MM:SS TZ"
  defp parse_rfc822(s) do
    s = strip_day_of_week(s)

    with {:ok, {day, month, year, hour, min, sec, tz_offset}} <- extract_rfc822_parts(s),
         {:ok, naive} <- NaiveDateTime.new(year, month, day, hour, min, sec),
         {:ok, dt} <- DateTime.from_naive(naive, "Etc/UTC") do
      {:ok, DateTime.add(dt, -tz_offset, :second)}
    else
      _ -> {:error, :invalid_date}
    end
  end

  defp strip_day_of_week(s) do
    case Regex.run(~r/^[A-Za-z]+,\s*(.*)$/, s) do
      [_, rest] -> rest
      _ -> s
    end
  end

  defp extract_rfc822_parts(s) do
    case Regex.run(
           ~r/^(\d{1,2})\s+([A-Za-z]+)\s+(\d{2,4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(.*)$/,
           s
         ) do
      [_, day_s, mon_s, year_s, h_s, m_s, sec_s, tz_s] ->
        with {day, _} <- Integer.parse(day_s),
             {:ok, month} <- month_number(mon_s),
             year <- normalize_year(year_s),
             {hour, _} <- Integer.parse(h_s),
             {min, _} <- Integer.parse(m_s),
             sec <- parse_seconds(sec_s),
             {:ok, tz_offset} <- parse_timezone(String.trim(tz_s)) do
          {:ok, {day, month, year, hour, min, sec, tz_offset}}
        else
          _ -> {:error, :invalid_date}
        end

      _ ->
        {:error, :invalid_date}
    end
  end

  defp parse_seconds(""), do: 0

  defp parse_seconds(s) do
    case Integer.parse(s) do
      {n, _} -> n
      :error -> 0
    end
  end

  defp normalize_year(s) do
    case Integer.parse(s) do
      {y, _} when y < 70 -> 2000 + y
      {y, _} when y < 100 -> 1900 + y
      {y, _} -> y
    end
  end

  defp month_number(s) do
    key = String.downcase(s)

    case Map.fetch(@month_map, key) do
      {:ok, _} = ok -> ok
      :error -> {:error, :unknown_month}
    end
  end

  defp parse_timezone(""), do: {:ok, 0}

  defp parse_timezone(tz) do
    cond do
      Regex.match?(~r/^[+-]\d{4}$/, tz) ->
        {sign, rest} = String.split_at(tz, 1)
        {hours, _} = Integer.parse(String.slice(rest, 0, 2))
        {mins, _} = Integer.parse(String.slice(rest, 2, 2))
        offset = hours * 3600 + mins * 60
        {:ok, if(sign == "-", do: -offset, else: offset)}

      Map.has_key?(@named_tz_offsets, String.upcase(tz)) ->
        {:ok, Map.fetch!(@named_tz_offsets, String.upcase(tz))}

      Regex.match?(~r/^[A-Za-z]+$/, tz) ->
        # Unknown named tz or military letter -> treat as UTC
        {:ok, 0}

      true ->
        {:ok, 0}
    end
  end

  # ISO 8601
  defp parse_iso8601(s) do
    case DateTime.from_iso8601(s) do
      {:ok, dt, _offset} -> {:ok, DateTime.shift_zone!(dt, "Etc/UTC")}
      _ -> {:error, :invalid_date}
    end
  end

  # Full month name: "October 4, 2007" or "October 04, 2007"
  defp parse_full_month(s) do
    case Regex.run(~r/^([A-Za-z]+)\s+(\d{1,2}),?\s+(\d{4})$/, s) do
      [_, month_s, day_s, year_s] ->
        key = String.downcase(month_s)

        with {:ok, month} <- Map.fetch(@full_month_map, key),
             {day, _} <- Integer.parse(day_s),
             {year, _} <- Integer.parse(year_s),
             {:ok, naive} <- NaiveDateTime.new(year, month, day, 0, 0, 0),
             {:ok, dt} <- DateTime.from_naive(naive, "Etc/UTC") do
          {:ok, dt}
        else
          _ -> {:error, :invalid_date}
        end

      _ ->
        {:error, :invalid_date}
    end
  end

  # Unix timestamp as string
  defp parse_unix_timestamp(s) do
    case Integer.parse(s) do
      {ts, ""} when ts > 0 ->
        {:ok, DateTime.from_unix!(ts)}

      _ ->
        {:error, :invalid_date}
    end
  end
end
