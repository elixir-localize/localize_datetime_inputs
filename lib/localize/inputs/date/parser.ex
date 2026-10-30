defmodule Localize.Inputs.Date.Parser do
  @moduledoc """
  Front-door parser for locale-aware date form input.

  Delegates to `Calendrical.Date.parse/2`. The input layer does
  no parsing of its own — this module is a thin policy layer
  over the underlying CLDR-driven parser: it names the calendar
  by its module, and returns the date in that calendar or in
  `Calendar.ISO`.

  """

  @doc """
  Parses a locale-formatted date string.

  Tries, in order: bare ISO-8601 (`YYYY-MM-DD`), then every
  CLDR `availableFormats` skeleton for the (locale, calendar)
  tuple. Skeletons encode the locale's preferred field order
  (and any era / week-numbering / quarter conventions), so the
  same input may parse to different dates under different
  locales — by design.

  Returns a `Date` in the calendar module given as the
  `:calendar` option — `Calendar.ISO` (the default),
  `Calendrical.Hebrew`, `Calendrical.Japanese`, and so on. Pass
  `return_calendar: :iso` to force the result into Gregorian
  regardless.

  ### Arguments

  * `string` is the raw user input: a string, or `nil` for a blank
    field.

  * `options` is a keyword list of options.

  ### Options

  * `:locale` — the locale to interpret the string under. Defaults
    to `Localize.get_locale/0`.

  * `:calendar` — the calendar module whose patterns to try AND
    the calendar of the returned `Date`, such as
    `Calendrical.Hebrew`. Defaults to `Calendar.ISO`. A CLDR
    calendar type, such as `:hebrew`, is not a calendar and is
    refused.

  * `:reference_date` — the "today" anchor used for two-digit-year
    pivoting. Defaults to `Date.utc_today/0`.

  * `:return_calendar` — `:native` (default) returns the parsed
    date in whatever `:calendar` named. `:iso` forces
    `Calendar.ISO`.

  ### Returns

  * `{:ok, Date.t()}` on success.

  * `{:ok, nil}` for blank input.

  * `{:error, Exception.t()}` on parse failure, an unknown
    `:calendar`, a `:return_calendar` other than `:native` or
    `:iso`, or a `string` that is neither a string nor `nil`.

  ### Examples

      iex> Localize.Inputs.Date.Parser.parse_date("2026-05-16", locale: :en)
      {:ok, ~D[2026-05-16]}

      iex> Localize.Inputs.Date.Parser.parse_date("5/16/26", locale: :en)
      {:ok, ~D[2026-05-16]}

      iex> Localize.Inputs.Date.Parser.parse_date("16/05/2026", locale: :"en-GB")
      {:ok, ~D[2026-05-16]}

      iex> Localize.Inputs.Date.Parser.parse_date("16.05.2026", locale: :de)
      {:ok, ~D[2026-05-16]}

      iex> Localize.Inputs.Date.Parser.parse_date("Q2 2026", locale: :en)
      {:ok, ~D[2026-04-01]}

      iex> Localize.Inputs.Date.Parser.parse_date("week 20 of 2026", locale: :en)
      {:ok, ~D[2026-05-10]}

      iex> Localize.Inputs.Date.Parser.parse_date("Saturday, May 16, 2026", locale: :en)
      {:ok, ~D[2026-05-16]}

      iex> Localize.Inputs.Date.Parser.parse_date("2026-05-16", locale: :en, calendar: Calendrical.Hebrew)
      {:ok, ~D[5786-08-29 Calendrical.Hebrew]}

      iex> Localize.Inputs.Date.Parser.parse_date("2026-05-16", locale: :en, calendar: Calendrical.Hebrew, return_calendar: :iso)
      {:ok, ~D[2026-05-16]}

      iex> {:error, %Localize.UnknownCalendarError{}} =
      ...>   Localize.Inputs.Date.Parser.parse_date("2026-05-16", locale: :en, calendar: :hebrew)

      iex> Localize.Inputs.Date.Parser.parse_date("", locale: :en)
      {:ok, nil}

  """
  @spec parse_date(term(), Keyword.t()) ::
          {:ok, Date.t() | nil} | {:error, Exception.t()}
  def parse_date(string, options \\ [])
  def parse_date(nil, _options), do: {:ok, nil}
  def parse_date("", _options), do: {:ok, nil}

  def parse_date(string, options) when is_binary(string) do
    {return_calendar, options} = Keyword.pop(options, :return_calendar, :native)

    with {:ok, options} <- validate_calendar(options),
         {:ok, date} <- Calendrical.Date.parse(String.trim(string), options) do
      in_return_calendar(date, return_calendar)
    end
  end

  # A form field sent more than once arrives as a list, and a
  # nested field as a map, so a value that is neither a string
  # nor `nil` reaches this function on a consumer request path.
  # It answers an error there rather than raising.
  def parse_date(value, _options) do
    {:error,
     Localize.InvalidValueError.exception(
       value: value,
       expected: "a date string or nil"
     )}
  end

  # A calendar is a module, and the caller's module is passed to
  # Calendrical unchanged. A CLDR calendar type, such as `:hebrew`, is
  # refused rather than resolved to a module: several calendars share
  # one CLDR type — the Vietnamese and Chinese calendars, a fiscal
  # calendar and Gregorian — so resolving it would silently answer in a
  # calendar the caller did not name.
  defp validate_calendar(options) do
    case Keyword.fetch(options, :calendar) do
      :error -> {:ok, options}
      {:ok, calendar} -> validated_calendar(options, calendar)
    end
  end

  # `Calendrical.calendar_module?/1` is false for `Calendar.ISO`, which
  # Calendrical did not compile, so it is named here.
  defp validated_calendar(options, Calendar.ISO), do: {:ok, options}

  defp validated_calendar(options, calendar) when is_atom(calendar) do
    if Calendrical.calendar_module?(calendar) do
      {:ok, options}
    else
      {:error, Localize.UnknownCalendarError.exception(calendar: calendar)}
    end
  end

  defp validated_calendar(_options, calendar),
    do: {:error, Localize.UnknownCalendarError.exception(calendar: calendar)}

  defp in_return_calendar(date, :native), do: {:ok, date}
  defp in_return_calendar(date, :iso), do: Calendrical.convert(date, Calendar.ISO)

  defp in_return_calendar(_date, return_calendar) do
    {:error,
     Localize.InvalidValueError.exception(
       value: return_calendar,
       expected: :return_calendar,
       allowed_values: [:native, :iso]
     )}
  end
end
