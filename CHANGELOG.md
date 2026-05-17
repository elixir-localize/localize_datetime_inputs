# Changelog

## [v0.1.0] — 2026-05-17

Extracted from `localize_inputs` 0.3 alongside `localize_number_inputs` and `localize_inputs_core`. Carries the date form input components — date_input, date_range_input, date_range_picker, and the `DatePickerLive` LiveComponent — plus their parser, validator, and Ecto Changeset bridge. Depends on `calendrical` for multi-calendar (Gregorian, Buddhist, Japanese, Islamic, Persian, Hebrew, ROC, …) parsing.

### Added

* Requires `calendrical ~> 0.5`. Picks up the broader TR35 parser coverage (every `availableFormats` skeleton, quarter / week / day-of-year / weekday-validation date fields, flex day periods, time-zone resolution) and the new calendar-preserving parse return — `Localize.Inputs.Date.Parser.parse_date/2` now returns a `Date` in the calendar named by the `:calendar` option (e.g. `~D[5786-09-29 Calendrical.Hebrew]`).

* `Localize.Inputs.Date.Components.format_date_for_display/4` now passes `:calendar` through to `Calendrical.Date.parse/2` when re-parsing string-form field values, so inputs like `"令和8年5月17日"` (Japanese imperial) round-trip without falling through to a Gregorian re-interpretation.

* Dropped the `Code.ensure_loaded?(Calendrical)` guards from `format_date_for_display` and `DatePickerLive.resolve_calendar_module/1`. `:calendrical` is a hard dependency, so the runtime check was dead weight.

* `convert_for_display` renamed to `ensure_calendar` and made idempotent (returns the date unchanged when it's already in the requested calendar).


