# Localize.Inputs.Date

Locale-aware date form input components for Phoenix LiveView:

* **`<.date_input>`** — locale-formatted text input + popup calendar grid. Accepts the locale's CLDR short/medium/long/full date patterns plus ISO-8601.

* **`<.date_range_input>` + `<.date_range_picker>`** — two-date pickers with a unified popover. Validates min/max bounds, span, weekday restrictions.

Built on top of [`localize`](https://hex.pm/packages/localize), [`calendrical`](https://hex.pm/packages/calendrical), and [`localize_inputs_core`](https://hex.pm/packages/localize_inputs_core). For number / unit-of-measure inputs install [`localize_number_inputs`](https://hex.pm/packages/localize_number_inputs) alongside.

Multi-calendar support (Gregorian, Buddhist, Japanese imperial, Islamic, Persian, Hebrew, ROC, …) comes via `calendrical` — users can type dates in their locale's calendar and the server parses correctly.

## Installation

```elixir
def deps do
  [
    {:localize_datetime_inputs, "~> 0.2"},

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
```

Import via `import Localize.Inputs.Date.Components` in your view module. Parse server-side via `Localize.Inputs.Date.Parser.parse_date/2` or `Calendrical.Date.parse/2`.

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

## License

Apache-2.0.
