# Changelog

## [v0.1.0] — 2026-05-17

Extracted from `localize_inputs` 0.3 alongside `localize_number_inputs` and `localize_inputs_core`. Carries the date form input components — date_input, date_range_input, date_range_picker, and the `DatePickerLive` LiveComponent — plus their parser, validator, and Ecto Changeset bridge. Depends on `calendrical` for multi-calendar (Gregorian, Buddhist, Japanese, Islamic, Persian, Hebrew, ROC, …) parsing.

### Added

* Requires `calendrical ~> 0.5`. Picks up the broader TR35 parser coverage (every `availableFormats` skeleton, quarter / week / day-of-year / weekday-validation date fields, flex day periods, time-zone resolution) and the new calendar-preserving parse return — `Localize.Inputs.Date.Parser.parse_date/2` now returns a `Date` in the calendar named by the `:calendar` option (e.g. `~D[5786-09-29 Calendrical.Hebrew]`).

* Display formatting re-parses string field values under the component's `:calendar`, so inputs like `"令和8年5月17日"` (Japanese imperial) round-trip without falling through to a Gregorian re-interpretation.

* Internal cleanups now that `:calendrical` is a hard dependency — runtime `Code.ensure_loaded?` guards removed, calendar-conversion helper made idempotent.


