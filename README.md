# Localize.Inputs.Date

Locale-aware date form input components for Phoenix LiveView, built on top of [`localize`](https://hex.pm/packages/localize), [`calendrical`](https://hex.pm/packages/calendrical), and [`localize_inputs_core`](https://hex.pm/packages/localize_inputs_core). For number and unit-of-measure inputs install [`localize_number_inputs`](https://hex.pm/packages/localize_number_inputs) alongside.

## Features

* **`<.date_input>`** — locale-formatted text input and popup calendar grid. Accepts the locale's CLDR short, medium, long and full date patterns plus ISO-8601.

* **`<.date_range_input>` and `<.date_range_picker>`** — two-date pickers with a unified popover. Validates min and max bounds, span, and weekday restrictions.

* **Multi-calendar** — a `:calendar` attribute takes a calendar module, such as `Calendrical.Hebrew`, `Calendrical.Japanese` or `Calendrical.Islamic.Civil`, and defaults to `Calendar.ISO`. Users type dates in that calendar and the server parses them in it.

## Supported Elixir and OTP versions

Requires **Elixir 1.17** and **OTP 26** or later.

## Installation

```elixir
def deps do
  [
    {:localize_datetime_inputs, "~> 0.3"},

    # Activate the HEEx components:
    {:phoenix_html, "~> 4.0"},
    {:phoenix_live_view, "~> 1.0"}
  ]
end
```

## Quick start

```heex
<.date_input form={@form} field={:dob} />

<.date_input
  form={@form}
  field={:start_date}
  min={~D[2026-01-01]}
  max={~D[2026-12-31]}
  display_format={:long}
/>

<.date_range_input form={@form} field={:vacation} />

<.date_input form={@form} field={:dob} calendar={Calendrical.Hebrew} locale={:"he-IL"} />
```

Import via `import Localize.Inputs.Date.Components` in your view module. Parse server-side via `Localize.Inputs.Date.Parser.parse_date/2` or `Calendrical.Date.parse/2`.

A `:calendar` is always a calendar module, never a CLDR calendar type: one CLDR type can name several calendars — `:gregorian` names both `Calendar.ISO` and `Calendrical.Gregorian` — so `calendar={:hebrew}` is refused rather than resolved on your behalf.

## CSS

```css
@import "../../deps/localize_inputs_core/priv/static/localize_inputs_core.css";
@import "../../deps/localize_datetime_inputs/priv/static/localize_datetime_inputs.css";
```

The token set is in `localize_inputs_core`; this package just adds component-specific rules.

## JS

```javascript
import Hooks from "../../deps/localize_datetime_inputs/priv/static/localize_datetime_inputs.js"

new LiveSocket("/live", Socket, {
  hooks: { DatePicker: Hooks.DatePicker, DateRangePicker: Hooks.RangePicker }
})
```

The date picker grid uses the browser's built-in `Intl.DateTimeFormat` — no additional JS peer dependencies. Without the hooks loaded the input still works as a plain text field; the server-side parser accepts whatever the user typed on submit.

## Documentation

* **[Localize.Inputs.Date.Components](https://hexdocs.pm/localize_datetime_inputs/Localize.Inputs.Date.Components.html)** — the `<.date_input>`, `<.date_range_input>` and `<.date_range_picker>` components and their attributes.

* **[Localize.Inputs.Date.Components.DatePickerLive](https://hexdocs.pm/localize_datetime_inputs/Localize.Inputs.Date.Components.DatePickerLive.html)** — the server-rendered multi-calendar grid.

* **[Localize.Inputs.Date.Parser](https://hexdocs.pm/localize_datetime_inputs/Localize.Inputs.Date.Parser.html)** — server-side parsing of a locale-formatted date string.

* **[Localize.Inputs.Date.Validator](https://hexdocs.pm/localize_datetime_inputs/Localize.Inputs.Date.Validator.html)** — bounds, span and weekday validation of a parsed date.

Full documentation is at [https://hexdocs.pm/localize_datetime_inputs](https://hexdocs.pm/localize_datetime_inputs).

## License

Apache-2.0. See [LICENSE.md](https://github.com/elixir-localize/localize_datetime_inputs/blob/v0.3.0/LICENSE.md).
