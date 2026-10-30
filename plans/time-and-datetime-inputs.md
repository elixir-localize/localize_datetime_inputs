# Time and datetime inputs

The package is named `localize_datetime_inputs` and ships date components only. This plan closes that gap.

## Current state

Everything under `lib/localize/inputs/date/`, exposed as `Localize.Inputs.Date.Components`:

| component | what it does |
|-----------|--------------|
| `date_input/1` | locale-formatted text input plus popup calendar grid |
| `date_range_input/1` | two-date entry with min/max, span and weekday restrictions |
| `date_range_picker/1` | the unified popover the range input opens |

Supported by `Localize.Inputs.Date.Parser` (a delegation to `Calendrical.Date.parse/2`), `Localize.Inputs.Date.Validator`, and the `DatePickerLive` LiveView.

There is no time or datetime component, and no `time/` or `datetime/` directory.

## Why this is mostly assembly

The hard parts are already solved upstream, which is what makes this worth scheduling rather than deferring:

* **Parsing** — `Calendrical.Time.parse/2` is locale-aware and lenient about the shapes a user actually types: `parse("2:30 PM", locale: :en)` and `parse("14:30", locale: :de)` both yield `~T[14:30:00]`. It also accepts partial input through `as: :map`, returning `%{hour: 11}` for `"11 am"` — which is exactly what a field needs while the user is still typing. `Calendrical.DateTime.parse/2` covers the combined case, and `Calendrical.parse/2` dispatches across date, time, naive datetime, datetime and range.

* **Formatting and the hour cycle** — `Localize.Time.to_string/2` already resolves 12- versus 24-hour from the locale: `en` renders `"2:30 PM"`, `en-GB`, `de` and `ja` render `"14:30"`, `ar-EG` renders Arabic day-period markers. The component does not need to reason about hour cycles to *display* a value; it only needs them to lay out a picker (see open questions).

So the work is component surface, validation, and the picker UI — not calendar or parsing machinery.

## 1. `time_input`

Mirror `date_input/1`, substituting the time equivalents.

### Plan

1. New `lib/localize/inputs/time/` alongside `date/`, with `Components`, `Parser` and `Validator` modules following the existing shapes. `Parser.parse_time/2` delegates to `Calendrical.Time.parse/2` exactly as `parse_date/2` delegates today.

2. Attribute set mirroring `date_input/1` — `:form`, `:field`, `:value`, `:locale`, `:min`, `:max`, `:placeholder`, `:display_format`, `:js`, and the `:class` / `:input_class` / `:button_class` / `:overlay_class` hooks — with `:min` and `:max` taking `Time` structs and `:display_format` taking `:short | :medium | :long | :full`, the same set `Localize.Time.to_string/2` accepts.

3. Add a `:granularity` attribute — `:minute` (default), `:second`, or a step in minutes — since a time field far more often wants quarter-hours than arbitrary precision. This has no date-side equivalent.

4. Wire value is ISO 8601 (`"14:30:00"`), matching the date components' rule that the display is locale-formatted and the wire value is not.

5. `Validator.validate_time/2` covering min/max bounds and granularity conformance, mirroring `validate_date/2`.

## 2. `datetime_input`

### Plan

1. `lib/localize/inputs/datetime/` with the same three modules. `Parser.parse_datetime/2` delegates to `Calendrical.DateTime.parse/2`.

2. Compose rather than reimplement: the component renders a date field and a time field side by side, sharing one popover, and combines them into a single `NaiveDateTime` wire value. The alternative — one text field accepting a full datetime string — parses fine but is poor entry UX, and the CLDR datetime patterns are built by joining a date and a time pattern anyway.

3. Decide the timezone story before building. `NaiveDateTime` is the honest default for a form field, since a browser cannot know which zone the user means. A `:time_zone` attribute promoting the result to `DateTime` is the natural extension, but it needs a rule for ambiguous and skipped wall-clock times across DST transitions — the case where a naive time either happens twice or not at all.

4. `validate_datetime/2` covering min/max on the combined value, not on the parts independently.

## Shared work

* Extract whatever the date popover machinery has that is not date-specific into `localize_inputs_core`, rather than copying it a second and third time. Worth doing while adding the second component, not the third.

* One `Localize.Inputs.DateTime.Components` façade re-exporting all three families, so a consumer writes a single `use`.

* README rewrite: it currently opens `# Localize.Inputs.Date` and describes the package as date components, which will be wrong on the first of these.

## Open questions

* **Picker layout for 12-hour locales.** Display comes free from `Localize.Time.to_string/2`, but a picker needs to know whether to show 1–12 with an AM/PM toggle or 0–23. Derivable from CLDR's `hours` preference data or by inspecting the locale's formatted output; the latter is a hack that happens to work. Settle it before building the picker.

* **Granularity vocabulary.** `:minute` / `:second` reads clearly, but a 15-minute step is the common real requirement. Whether that is `granularity: 15`, `step: 15`, or both needs deciding once rather than twice.

* **Does `time_range_input` follow?** The date side has ranges. A time range is a smaller and less common need, and nothing forces it to land in the same release.

## API impact

Purely additive — new modules and components, no change to the date family. The package name stops over-promising.
