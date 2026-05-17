defmodule Localize.Inputs.Date.Parser do
  @moduledoc """
  Front-door parser for locale-aware date form input.

  Delegates to `Calendrical.Date.parse/2`. The input layer does
  no parsing of its own — this module is a thin policy layer
  over the underlying CLDR-driven parser.

  """

  @doc """
  Parses a locale-formatted date string.

  Tries, in order: bare ISO-8601 (`YYYY-MM-DD`), then every
  CLDR `availableFormats` skeleton for the (locale, calendar)
  tuple. Skeletons encode the locale's preferred field order
  (and any era / week-numbering / quarter conventions), so the
  same input may parse to different dates under different
  locales — by design.

  Returns a `Date` in the calendar identified by the `:calendar`
  option — `Calendar.ISO` for `:gregorian` (the default),
  `Calendrical.Hebrew` for `:hebrew`, `Calendrical.Japanese` for
  `:japanese`, and so on. Pass `return_calendar: :iso` to force
  the result into Gregorian regardless.

  ### Arguments

  * `string` is the raw user input.

  * `options` is a keyword list of options.

  ### Options

  * `:locale` — the locale to interpret the string under. Defaults
    to `Localize.get_locale/0`.

  * `:calendar` — the CLDR calendar key whose patterns to try
    AND the calendar of the returned `Date`. Defaults to
    `:gregorian`.

  * `:reference_date` — the "today" anchor used for two-digit-year
    pivoting. Defaults to `Date.utc_today/0`.

  * `:return_calendar` — `:native` (default) returns the parsed
    date in whatever `:calendar` named. `:iso` forces
    `Calendar.ISO`.

  ### Returns

  * `{:ok, Date.t()}` on success.

  * `{:ok, nil}` for blank input.

  * `{:error, Exception.t()}` on parse failure.

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
      {:ok, ~D[2026-05-11]}

      iex> Localize.Inputs.Date.Parser.parse_date("Saturday, May 16, 2026", locale: :en)
      {:ok, ~D[2026-05-16]}

      iex> Localize.Inputs.Date.Parser.parse_date("2026-05-16", locale: :en, calendar: :hebrew)
      {:ok, ~D[5786-09-29 Calendrical.Hebrew]}

      iex> Localize.Inputs.Date.Parser.parse_date("", locale: :en)
      {:ok, nil}

  """
  @spec parse_date(String.t() | nil, Keyword.t()) ::
          {:ok, Date.t() | nil} | {:error, Exception.t()}
  def parse_date(string, options \\ [])
  def parse_date(nil, _options), do: {:ok, nil}
  def parse_date("", _options), do: {:ok, nil}

  def parse_date(string, options) when is_binary(string) do
    Calendrical.Date.parse(String.trim(string), options)
  end
end
