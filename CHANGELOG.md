# Changelog

## [v0.1.1] — 2026-05-17

### Bug Fixes

* `<.date_input>` and `DatePickerLive` no longer raise on a date that can't be converted into the requested calendar. `Date.convert!/2` and `Date.new!/3,4` replaced throughout with tolerant `safe_convert/2` and `safe_build_date/4` helpers that fall back to the input date or today rather than crashing the render path.

* `<.date_range_input>` switched from `String.to_atom/1` to `String.to_existing_atom/1` when deriving the `{field}_from` / `{field}_to` child fields, preventing atom-table pollution from user-supplied field names. Consumers' schemas already define these atoms for form parsing to work, so this is invisible in practice.

## [v0.1.0] — 2026-05-17

Extracted from `localize_inputs` 0.3 alongside `localize_number_inputs` and `localize_inputs_core`. Carries the date form input components — date_input, date_range_input, date_range_picker, and the `DatePickerLive` LiveComponent — plus their parser, validator, and Ecto Changeset bridge. Depends on `calendrical` for multi-calendar (Gregorian, Buddhist, Japanese, Islamic, Persian, Hebrew, ROC, …) parsing.

### Added

* Requires `calendrical ~> 0.5`. Picks up the broader TR35 parser coverage (every `availableFormats` skeleton, quarter / week / day-of-year / weekday-validation date fields, flex day periods, time-zone resolution) and the new calendar-preserving parse return — `Localize.Inputs.Date.Parser.parse_date/2` now returns a `Date` in the calendar named by the `:calendar` option (e.g. `~D[5786-09-29 Calendrical.Hebrew]`).

* Display formatting re-parses string field values under the component's `:calendar`, so inputs like `"令和8年5月17日"` (Japanese imperial) round-trip without falling through to a Gregorian re-interpretation.

* Internal cleanups now that `:calendrical` is a hard dependency — runtime `Code.ensure_loaded?` guards removed, calendar-conversion helper made idempotent.


