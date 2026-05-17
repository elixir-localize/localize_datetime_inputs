defmodule Localize.Inputs.Date.Validator do
  @moduledoc """
  Server-side validation for parsed date and date-range values.

  Pure Elixir, no Ecto dependency. The Ecto changeset bridge is
  in `Localize.Inputs.Date.Changeset`.

  """

  alias Localize.Inputs.ValidationError

  @doc """
  Validates a parsed `t:Date.t/0` against bounds, weekday
  restrictions, and required-ness.

  ### Arguments

  * `value` is a `t:Date.t/0` or `nil`.

  * `options` is a keyword list of options.

  ### Options

  * `:required` — when `true`, `nil` is rejected.

  * `:min` — minimum allowed date (`Date` or ISO-8601 string).

  * `:max` — maximum allowed date.

  * `:not_weekend` — when `true`, rejects Saturday and Sunday.
    To customise which weekdays count as "weekend" per
    locale, pass `:weekend_days` as a list of
    1..7 (1 = Monday).

  * `:on_or_after` — alias for `:min`. When both are given,
    the stricter (later) bound wins.

  * `:on_or_before` — alias for `:max`. When both are given,
    the stricter (earlier) bound wins.

  * `:business_days_only` — when `true`, rejects any date
    falling on the locale's weekend (per `:weekend_days` or
    the default `[6, 7]` = Sat/Sun). Equivalent to
    `:not_weekend` but with the more business-domain
    naming. Future extensions may also reject locale-aware
    public holidays via a `:holidays` option (not yet
    wired).

  ### Returns

  * `:ok` when every check passes.

  * `{:error, %Localize.Inputs.ValidationError{errors: [{atom(),
    String.t()}]}}` with one entry per failing check, in the
    order `:required`, `:min`, `:max`, `:weekend`.

  ### Examples

      iex> Localize.Inputs.Date.Validator.validate_date(~D[2026-05-16], min: ~D[2026-01-01])
      :ok

      iex> {:error, %Localize.Inputs.ValidationError{errors: errors}} =
      ...>   Localize.Inputs.Date.Validator.validate_date(~D[2025-01-01], min: ~D[2026-01-01])
      iex> Keyword.get(errors, :min) =~ "2026-01-01"
      true

      iex> {:error, %Localize.Inputs.ValidationError{errors: errors}} =
      ...>   Localize.Inputs.Date.Validator.validate_date(nil, required: true)
      iex> errors
      [{:required, "is required"}]

  """
  @spec validate_date(term(), Keyword.t()) :: :ok | {:error, ValidationError.t()}
  def validate_date(value, options \\ []) do
    options = normalize_date_options(options)

    errors =
      []
      |> check_date_required(value, options)
      |> check_date_range(value, options)
      |> check_date_weekend(value, options)
      |> Enum.reverse()

    if errors == [], do: :ok, else: {:error, ValidationError.exception(errors: errors)}
  end

  # Fold `:on_or_after` / `:on_or_before` aliases into
  # `:min` / `:max`, preferring the stricter bound when
  # both are present. `:business_days_only` is a synonym for
  # `:not_weekend`.
  defp normalize_date_options(options) do
    options
    |> merge_bound(:on_or_after, :min, &keep_later/2)
    |> merge_bound(:on_or_before, :max, &keep_earlier/2)
    |> alias_weekend()
  end

  defp merge_bound(options, alias_key, canonical_key, merger) do
    case Keyword.pop(options, alias_key) do
      {nil, options} ->
        options

      {alias_value, options} ->
        Keyword.update(options, canonical_key, alias_value, fn existing ->
          merger.(existing, alias_value)
        end)
    end
  end

  defp keep_later(a, b), do: pick_date(a, b, :gt)
  defp keep_earlier(a, b), do: pick_date(a, b, :lt)

  defp pick_date(a, b, preferred_cmp) do
    with {:ok, a_date} <- to_date(a),
         {:ok, b_date} <- to_date(b) do
      if Date.compare(a_date, b_date) == preferred_cmp, do: a, else: b
    else
      _ -> a
    end
  end

  defp alias_weekend(options) do
    case Keyword.pop(options, :business_days_only) do
      {true, options} -> Keyword.put_new(options, :not_weekend, true)
      {_, options} -> options
    end
  end

  @doc """
  Validates a parsed `t:Date.Range.t/0` against bounds, span,
  weekend restrictions, and required-ness.

  ### Arguments

  * `value` is a `t:Date.Range.t/0` or `nil`.

  * `options` is a keyword list of options.

  ### Options

  * `:required` — when `true`, `nil` is rejected.

  * `:min`, `:max` — bounds that both endpoints must satisfy.

  * `:min_span` — minimum span in days (inclusive of both
    endpoints, so `~D[2026-01-01]..~D[2026-01-03]` has span 3).

  * `:max_span` — maximum span in days.

  * `:disallow_inverted` — when `true`, rejects descending
    ranges. The range parser already rejects inverted ranges
    by default; this is here for direct validator use.

  ### Returns

  * `:ok` when every check passes.

  * `{:error, ValidationError.t()}` with errors keyed by
    `:required`, `:min`, `:max`, `:min_span`, `:max_span`,
    `:inverted`.

  ### Examples

      iex> range = Date.range(~D[2026-05-01], ~D[2026-05-07])
      iex> Localize.Inputs.Date.Validator.validate_date_range(range, min_span: 5, max_span: 10)
      :ok

      iex> range = Date.range(~D[2026-05-01], ~D[2026-05-03])
      iex> {:error, %Localize.Inputs.ValidationError{errors: errors}} =
      ...>   Localize.Inputs.Date.Validator.validate_date_range(range, min_span: 5)
      iex> Keyword.get(errors, :min_span) =~ "5"
      true

  """
  @spec validate_date_range(term(), Keyword.t()) :: :ok | {:error, ValidationError.t()}
  def validate_date_range(value, options \\ []) do
    errors =
      []
      |> check_range_required(value, options)
      |> check_range_inversion(value, options)
      |> check_range_endpoints(value, options)
      |> check_range_span(value, options)
      |> Enum.reverse()

    if errors == [], do: :ok, else: {:error, ValidationError.exception(errors: errors)}
  end

  # ── Date checks ─────────────────────────────────────────────

  defp check_date_required(errors, nil, options) do
    if Keyword.get(options, :required, false) do
      [{:required, "is required"} | errors]
    else
      errors
    end
  end

  defp check_date_required(errors, _value, _options), do: errors

  defp check_date_range(errors, nil, _options), do: errors

  defp check_date_range(errors, %Date{} = value, options) do
    errors
    |> maybe_check_date_min(value, Keyword.get(options, :min))
    |> maybe_check_date_max(value, Keyword.get(options, :max))
  end

  defp check_date_range(errors, _, _), do: errors

  defp maybe_check_date_min(errors, _value, nil), do: errors

  defp maybe_check_date_min(errors, value, min) do
    case to_date(min) do
      {:ok, min_date} ->
        if Date.compare(value, min_date) == :lt do
          [{:min, "must be on or after #{Date.to_iso8601(min_date)}"} | errors]
        else
          errors
        end

      :error ->
        errors
    end
  end

  defp maybe_check_date_max(errors, _value, nil), do: errors

  defp maybe_check_date_max(errors, value, max) do
    case to_date(max) do
      {:ok, max_date} ->
        if Date.compare(value, max_date) == :gt do
          [{:max, "must be on or before #{Date.to_iso8601(max_date)}"} | errors]
        else
          errors
        end

      :error ->
        errors
    end
  end

  defp check_date_weekend(errors, nil, _options), do: errors

  defp check_date_weekend(errors, %Date{} = value, options) do
    if Keyword.get(options, :not_weekend, false) do
      weekend = Keyword.get(options, :weekend_days, [6, 7])

      if Date.day_of_week(value) in weekend do
        [{:weekend, "must not fall on a weekend"} | errors]
      else
        errors
      end
    else
      errors
    end
  end

  defp check_date_weekend(errors, _, _), do: errors

  # ── Range checks ────────────────────────────────────────────

  defp check_range_required(errors, nil, options) do
    if Keyword.get(options, :required, false) do
      [{:required, "is required"} | errors]
    else
      errors
    end
  end

  defp check_range_required(errors, _value, _options), do: errors

  defp check_range_inversion(errors, nil, _options), do: errors

  defp check_range_inversion(errors, %Date.Range{step: step}, options) do
    disallow = Keyword.get(options, :disallow_inverted, false)

    if disallow and step < 0 do
      [{:inverted, "range start must be on or before range end"} | errors]
    else
      errors
    end
  end

  defp check_range_inversion(errors, _, _), do: errors

  defp check_range_endpoints(errors, nil, _options), do: errors

  defp check_range_endpoints(errors, %Date.Range{first: first, last: last}, options) do
    errors
    |> maybe_check_date_min(first, Keyword.get(options, :min))
    |> maybe_check_date_max(last, Keyword.get(options, :max))
  end

  defp check_range_endpoints(errors, _, _), do: errors

  defp check_range_span(errors, nil, _options), do: errors

  defp check_range_span(errors, %Date.Range{first: first, last: last}, options) do
    span = abs(Date.diff(last, first)) + 1

    errors
    |> maybe_check_min_span(span, Keyword.get(options, :min_span))
    |> maybe_check_max_span(span, Keyword.get(options, :max_span))
  end

  defp check_range_span(errors, _, _), do: errors

  defp maybe_check_min_span(errors, _span, nil), do: errors

  defp maybe_check_min_span(errors, span, min_span) when is_integer(min_span) do
    if span < min_span do
      [{:min_span, "must span at least #{min_span} days"} | errors]
    else
      errors
    end
  end

  defp maybe_check_max_span(errors, _span, nil), do: errors

  defp maybe_check_max_span(errors, span, max_span) when is_integer(max_span) do
    if span > max_span do
      [{:max_span, "must span at most #{max_span} days"} | errors]
    else
      errors
    end
  end

  # Accept Date structs, ISO-8601 strings, or anything we can
  # coerce. Returns `:error` for nil/garbage rather than
  # raising so the caller can silently skip the bound.
  defp to_date(%Date{} = date), do: {:ok, date}

  defp to_date(string) when is_binary(string) do
    case Date.from_iso8601(string) do
      {:ok, date} -> {:ok, date}
      _ -> :error
    end
  end

  defp to_date(_), do: :error
end
