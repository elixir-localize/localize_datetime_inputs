if Code.ensure_loaded?(Phoenix.Component) and
     Code.ensure_loaded?(Gettext.Backend) do
  defmodule Localize.Inputs.Date.Components do
    @moduledoc """
    HEEx components for locale-aware date form input.

    Provides `date_input/1`, `date_range_input/1`, and
    `date_range_picker/1`. Built on `calendrical` for
    multi-calendar parsing (Gregorian, Buddhist, Japanese,
    Islamic, Persian, Hebrew, ROC, …).

    ## Setup

    Add the JS hooks in your `assets/js/app.js`:

        import Hooks from "localize_datetime_inputs"
        let liveSocket = new LiveSocket("/live", Socket, {
          hooks: {
            DatePicker: Hooks.DatePicker,
            DateRangePicker: Hooks.DateRangePicker
          }
        })

    ## Tolerance of invalid input

    These components sit on the render path and never raise on
    bad input — the page always renders. Specifically:

    * **Unknown `:locale`** — formatting falls back to
      whatever `Localize.Date.to_string/2` returns; on
      failure the cell renders the ISO-8601 form of the
      date (`2026-05-17`).

    * **Unknown `:calendar`** — date conversion uses a
      tolerant `Date.convert/2`; on failure the date is
      kept in its original calendar (typically
      `Calendar.ISO`) and rendered using whatever pattern
      lookup succeeds.

    * **Blank or unparseable `value`** — the visible text
      input renders empty; the hidden ISO carrier stays
      empty. `Localize.Inputs.Date.Parser.parse_date/2`
      returns `{:ok, nil}` for blanks and
      `{:error, %Calendrical.DateParseError{}}` for
      garbage, never raises.

    * **`date_range_input/1` child field atoms** — derives
      `{field}_from` and `{field}_to` via
      `String.to_existing_atom/1`. The atom must already
      exist (it does, because your changeset/schema defines
      it for form parsing); if it doesn't, an `ArgumentError`
      surfaces at render time and points at the missing field.

    * **`DatePickerLive` malformed cursor / month** — the
      server-rendered grid uses tolerant `safe_convert/2` and
      `safe_build_date/4` helpers. An invalid year/month
      combo for the target calendar falls back to today
      rather than 500ing the LiveView.

    """

    use Phoenix.Component
    use Localize.Message.Sigils, backend: Localize.Inputs.Gettext

    # ── date_input + date_picker + date_range_input ──────────

    @doc """
    Locale-aware date input with a popup calendar grid.

    Renders a text input that accepts the locale's CLDR date
    patterns plus ISO-8601, paired with a calendar-icon trigger
    that opens a Gregorian month grid for picking. Selecting a
    day fills the text input (locale-formatted) and a hidden
    sibling input (ISO wire format). On submit the form
    receives `params[field]` as `"YYYY-MM-DD"`.

    Server-side, parse with `Localize.Inputs.Date.Parser.parse_date/2`
    or `Calendrical.Date.parse/2`.

    Multi-calendar parsing works (Buddhist, Islamic, Japanese,
    etc.) — the user can type in their locale's calendar
    representation and the server parses correctly. The popup
    grid renders in Gregorian; non-Gregorian grid rendering
    is a follow-on enhancement.

    ### Attributes

    * `:form` — the `Phoenix.HTML.Form` the field belongs to.

    * `:field` — the form field as an atom.

    * `:value` — explicit ISO date string; otherwise pulled
      from `@form[@field]`.

    * `:locale` — display locale. Defaults to
      `Localize.get_locale/0`.

    * `:min`, `:max` — ISO date strings or `Date` structs.

    * `:placeholder` — placeholder text for the text input.

    * `:display_format` — one of `:short`, `:medium` (default),
      `:long`, `:full`. Controls the locale-formatted display
      shape; the wire value is always ISO.

    * `:js` — set to `false` to skip the `phx-hook` attribute.

    * `:class`, `:input_class`, `:button_class`,
      `:overlay_class` — customisation hooks.

    ### Examples

        <.date_input form={@form} field={:dob} />

        <.date_input
          form={@form}
          field={:start_date}
          min={~D[2026-01-01]}
          max={~D[2026-12-31]}
          display_format={:long}
        />

    """
    attr(:form, Phoenix.HTML.Form, required: true)
    attr(:field, :atom, required: true)
    attr(:value, :any, default: nil)
    attr(:locale, :any, default: nil)
    attr(:min, :any, default: nil)
    attr(:max, :any, default: nil)
    attr(:placeholder, :string, default: nil)
    attr(:display_format, :atom, default: :medium, values: [:short, :medium, :long, :full])
    attr(:calendar, :atom, default: :gregorian)
    attr(:variant, :atom, default: :auto, values: [:auto, :dropdown, :sheet])
    attr(:js, :boolean, default: true)
    attr(:class, :string, default: nil)
    attr(:input_class, :string, default: nil)
    attr(:button_class, :string, default: nil)
    attr(:overlay_class, :string, default: nil)
    attr(:rest, :global, include: ~w(disabled readonly required autofocus))

    def date_input(assigns) do
      assigns = assign_date_common(assigns)

      ~H"""
      <div
        class={["date-input-wrapper", @class]}
        id={"#{@id}-wrapper"}
        data-date-input
        data-locale={to_string(@locale)}
        data-display-format={Atom.to_string(@display_format)}
        data-calendar={cldr_to_intl_calendar(@calendar)}
        data-min={date_attr(@min)}
        data-max={date_attr(@max)}
        data-variant={to_string(@variant)}
        phx-hook={if @js, do: "DatePicker"}
      >
        <input
          type="text"
          inputmode="numeric"
          name={@name}
          id={@id}
          value={@formatted_value}
          class={["date-input-field", @input_class]}
          autocomplete="off"
          placeholder={@placeholder}
          aria-describedby={"#{@id}-hint"}
          {@rest}
        />
        <%!-- Canonical ISO carrier: the JS hook writes the
              picker's current selection here on every day
              click. It SUBMITS alongside the visible text
              input (as `<name>_iso`) so the server can
              prefer this lossless wire value over whatever
              the browser's `Intl.DateTimeFormat` rendered
              into the visible field (which varies by
              browser and isn't always parseable for
              non-Gregorian calendars). --%>
        <input
          type="hidden"
          name={"#{@name}_iso"}
          id={"#{@id}-iso"}
          value={iso_attr(@value, @field_value)}
          data-date-picker-value
        />
        <button
          type="button"
          class={["date-input-trigger", @button_class]}
          data-date-picker-trigger
          aria-haspopup="dialog"
          aria-expanded="false"
          aria-label={~t"Open calendar"}
        >
          <svg
            class="date-input-trigger-icon"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            aria-hidden="true"
          >
            <path d="M8 2v4" /><path d="M16 2v4" />
            <rect x="3" y="4" width="18" height="18" rx="2" />
            <path d="M3 10h18" />
          </svg>
        </button>
        <div
          class={["date-picker-overlay", @overlay_class]}
          data-date-picker-overlay
          role="dialog"
          aria-label={~t"Choose date"}
          hidden
        >
          <div class="date-picker-header">
            <button
              type="button"
              class="date-picker-nav"
              data-date-picker-prev
              aria-label={~t"Previous month"}
            >‹</button>
            <span class="date-picker-month-label" data-date-picker-month-label></span>
            <button
              type="button"
              class="date-picker-nav"
              data-date-picker-next
              aria-label={~t"Next month"}
            >›</button>
            <button
              type="button"
              class="date-picker-close"
              data-date-picker-close
              aria-label={~t"Close calendar"}
            >×</button>
          </div>
          <table class="date-picker-grid" data-date-picker-grid role="grid">
          </table>
        </div>
      </div>
      """
    end

    @doc """
    Locale-aware date-range input.

    Renders two paired text inputs (from / to) inside a single
    grouped wrapper. Each field is independently editable; the
    pair submits as `params[field] = %{"from" => "YYYY-MM-DD",
    "to" => "YYYY-MM-DD"}`.

    Server-side, parse with
    `Calendrical.Date.parse_range/2` passing the `{from, to}`
    tuple from `params[field]`.

    ### Attributes

    * `:form` — the `Phoenix.HTML.Form` the field belongs to.

    * `:field` — the form field as an atom; sub-fields submit
      under `params[field][from]` and `params[field][to]`.

    * `:locale`, `:min`, `:max`, `:display_format`, `:variant`,
      `:js` — passed through to both inputs.

    * `:class`, `:input_class`, `:button_class`,
      `:overlay_class` — customisation hooks.

    ### Examples

        <.date_range_input form={@form} field={:stay} />

        <.date_range_input
          form={@form}
          field={:trip}
          min={~D[2026-01-01]}
          max={~D[2026-12-31]}
        />

    """
    attr(:form, Phoenix.HTML.Form, required: true)
    attr(:field, :atom, required: true)
    attr(:locale, :any, default: nil)
    attr(:min, :any, default: nil)
    attr(:max, :any, default: nil)
    attr(:placeholder_from, :string, default: nil)
    attr(:placeholder_to, :string, default: nil)
    attr(:display_format, :atom, default: :medium, values: [:short, :medium, :long, :full])
    attr(:calendar, :atom, default: :gregorian)
    attr(:variant, :atom, default: :auto, values: [:auto, :dropdown, :sheet])
    attr(:js, :boolean, default: true)
    attr(:class, :string, default: nil)
    attr(:input_class, :string, default: nil)
    attr(:button_class, :string, default: nil)
    attr(:overlay_class, :string, default: nil)

    def date_range_input(assigns) do
      assigns = assign_date_range_common(assigns)

      ~H"""
      <div class={["date-range-input-wrapper", @class]} id={"#{@id}-wrapper"} data-date-range-input>
        <.date_input
          form={@form}
          field={String.to_existing_atom("#{@field}_from")}
          locale={@locale}
          min={@min}
          max={@max}
          display_format={@display_format}
          calendar={@calendar}
          variant={@variant}
          placeholder={@placeholder_from}
          js={@js}
          input_class={@input_class}
          button_class={@button_class}
          overlay_class={@overlay_class}
        />
        <span class="date-range-separator" aria-hidden="true">–</span>
        <.date_input
          form={@form}
          field={String.to_existing_atom("#{@field}_to")}
          locale={@locale}
          min={@min}
          max={@max}
          display_format={@display_format}
          calendar={@calendar}
          variant={@variant}
          placeholder={@placeholder_to}
          js={@js}
          input_class={@input_class}
          button_class={@button_class}
          overlay_class={@overlay_class}
        />
      </div>
      """
    end

    @doc """
    Locale-aware date-range input with a unified popup
    calendar (click start, then click end inside the same
    grid). Pairs with `RangePicker` JS hook.

    Renders two text inputs (visible "from" and "to") plus a
    single shared trigger and overlay. The user clicks the
    trigger to open the popup, clicks once for the start,
    hovers to preview, clicks again for the end. Both text
    inputs and both hidden ISO inputs populate.

    Submits as `params[field] = %{"from" => "YYYY-MM-DD",
    "to" => "YYYY-MM-DD"}`. Server-side, parse with
    `Calendrical.Date.parse_range/2` passing the
    `{from, to}` tuple.

    ### Attributes

    Same shape as `date_range_input/1`: `:form`, `:field`,
    `:locale`, `:min`, `:max`, `:display_format`,
    `:calendar`, `:variant`, `:js`, `:class`, etc.

    ### Examples

        <.date_range_picker form={@form} field={:stay} />

    """
    attr(:form, Phoenix.HTML.Form, required: true)
    attr(:field, :atom, required: true)
    attr(:locale, :any, default: nil)
    attr(:min, :any, default: nil)
    attr(:max, :any, default: nil)
    attr(:placeholder_from, :string, default: nil)
    attr(:placeholder_to, :string, default: nil)
    attr(:display_format, :atom, default: :medium, values: [:short, :medium, :long, :full])
    attr(:calendar, :atom, default: :gregorian)
    attr(:variant, :atom, default: :auto, values: [:auto, :dropdown, :sheet])
    attr(:js, :boolean, default: true)
    attr(:class, :string, default: nil)
    attr(:input_class, :string, default: nil)
    attr(:button_class, :string, default: nil)
    attr(:overlay_class, :string, default: nil)

    def date_range_picker(assigns) do
      assigns = assign_date_range_picker_common(assigns)

      ~H"""
      <div
        class={["date-range-picker", @class]}
        id={"#{@id}-wrapper"}
        data-date-input
        data-range-picker
        data-locale={to_string(@locale)}
        data-display-format={Atom.to_string(@display_format)}
        data-calendar={cldr_to_intl_calendar(@calendar)}
        data-min={date_attr(@min)}
        data-max={date_attr(@max)}
        data-variant={to_string(@variant)}
        phx-hook={if @js, do: "RangePicker"}
      >
        <input
          type="text"
          name={"#{@base_name}[from]"}
          id={"#{@id}-from"}
          value={@formatted_from}
          class={["date-input-field", "range-from-field", @input_class]}
          autocomplete="off"
          placeholder={@placeholder_from}
        />
        <input
          type="hidden"
          name={"#{@base_name}[from_iso]"}
          id={"#{@id}-from-iso"}
          value={iso_attr(nil, @from_value)}
          data-range-picker-from
        />
        <span class="date-range-separator" aria-hidden="true">–</span>
        <input
          type="text"
          name={"#{@base_name}[to]"}
          id={"#{@id}-to"}
          value={@formatted_to}
          class={["date-input-field", "range-to-field", @input_class]}
          autocomplete="off"
          placeholder={@placeholder_to}
        />
        <input
          type="hidden"
          name={"#{@base_name}[to_iso]"}
          id={"#{@id}-to-iso"}
          value={iso_attr(nil, @to_value)}
          data-range-picker-to
        />
        <button
          type="button"
          class={["date-input-trigger", @button_class]}
          data-date-picker-trigger
          aria-haspopup="dialog"
          aria-expanded="false"
          aria-label={~t"Open calendar"}
        >
          <svg
            class="date-input-trigger-icon"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            aria-hidden="true"
          >
            <path d="M8 2v4" /><path d="M16 2v4" />
            <rect x="3" y="4" width="18" height="18" rx="2" />
            <path d="M3 10h18" />
          </svg>
        </button>
        <div
          class={["date-picker-overlay", @overlay_class]}
          data-date-picker-overlay
          role="dialog"
          aria-label={~t"Choose date range"}
          hidden
        >
          <div class="date-picker-header">
            <button type="button" class="date-picker-nav" data-date-picker-prev aria-label={~t"Previous month"}>‹</button>
            <span class="date-picker-month-label" data-date-picker-month-label></span>
            <button type="button" class="date-picker-nav" data-date-picker-next aria-label={~t"Next month"}>›</button>
            <button type="button" class="date-picker-close" data-date-picker-close aria-label={~t"Close calendar"}>×</button>
          </div>
          <table class="date-picker-grid" data-date-picker-grid role="grid">
          </table>
        </div>
      </div>
      """
    end

    # ── Internal: date_input assigns ──────────────────────────

    defp assign_date_common(assigns) do
      locale = assigns[:locale] || Localize.get_locale()
      field_struct = assigns.form[assigns.field]
      name = field_struct.name
      id = field_struct.id
      field_value = field_struct.value

      formatted =
        format_date_for_display(
          assigns.value || field_value,
          locale,
          assigns.display_format,
          Map.get(assigns, :calendar, :gregorian)
        )

      assigns
      |> assign(:locale, locale)
      |> assign(:name, name)
      |> assign(:id, id)
      |> assign(:field_value, field_value)
      |> assign(:formatted_value, formatted)
      |> assign_new(:placeholder, fn -> nil end)
      |> assign_new(:class, fn -> nil end)
      |> assign_new(:input_class, fn -> nil end)
      |> assign_new(:button_class, fn -> nil end)
      |> assign_new(:overlay_class, fn -> nil end)
    end

    defp assign_date_range_common(assigns) do
      field_struct = assigns.form[assigns.field]
      id = field_struct.id

      assigns
      |> assign(:id, id)
      |> assign_new(:placeholder_from, fn -> nil end)
      |> assign_new(:placeholder_to, fn -> nil end)
      |> assign_new(:class, fn -> nil end)
      |> assign_new(:input_class, fn -> nil end)
      |> assign_new(:button_class, fn -> nil end)
      |> assign_new(:overlay_class, fn -> nil end)
    end

    defp assign_date_range_picker_common(assigns) do
      locale = assigns[:locale] || Localize.get_locale()
      field_struct = assigns.form[assigns.field]
      base_name = field_struct.name
      id = field_struct.id

      # Map-shaped field value: %{"from" => ..., "to" => ...}.
      {from_value, to_value} =
        case field_struct.value do
          %{"from" => f, "to" => t} -> {f, t}
          %{from: f, to: t} -> {f, t}
          _ -> {nil, nil}
        end

      assigns
      |> assign(:locale, locale)
      |> assign(:base_name, base_name)
      |> assign(:id, id)
      |> assign(:from_value, from_value)
      |> assign(:to_value, to_value)
      |> assign(
        :formatted_from,
        format_date_for_display(from_value, locale, assigns.display_format, assigns.calendar)
      )
      |> assign(
        :formatted_to,
        format_date_for_display(to_value, locale, assigns.display_format, assigns.calendar)
      )
      |> assign_new(:placeholder_from, fn -> nil end)
      |> assign_new(:placeholder_to, fn -> nil end)
      |> assign_new(:class, fn -> nil end)
      |> assign_new(:input_class, fn -> nil end)
      |> assign_new(:button_class, fn -> nil end)
      |> assign_new(:overlay_class, fn -> nil end)
    end

    defp format_date_for_display(nil, _locale, _format, _calendar), do: ""
    defp format_date_for_display("", _locale, _format, _calendar), do: ""

    defp format_date_for_display(%Date{} = date, locale, format, cldr_calendar) do
      # `Localize.Date.to_string/2` dispatches its CLDR pattern
      # lookup on `date.calendar`, so a `Calendar.ISO` date
      # always renders under `:gregorian` even when the
      # component received `calendar: :japanese`. Ensure the
      # date is in the requested calendar before formatting.
      display_date = ensure_calendar(date, cldr_calendar)

      case Localize.Date.to_string(display_date, locale: locale, format: format) do
        {:ok, string} -> string
        _ -> Date.to_iso8601(date)
      end
    end

    defp format_date_for_display(string, locale, format, cldr_calendar)
         when is_binary(string) do
      # Pass `:calendar` so the parser interprets the input
      # under the requested calendar (e.g. `"令和8年5月17日"`
      # under `:japanese`) AND returns a `Date` already tagged
      # with the right calendar module — no second-stage
      # conversion needed.
      case Calendrical.Date.parse(string, locale: locale, calendar: cldr_calendar) do
        {:ok, date} ->
          case Localize.Date.to_string(date, locale: locale, format: format) do
            {:ok, formatted} -> formatted
            _ -> string
          end

        _ ->
          string
      end
    end

    defp format_date_for_display(_, _, _, _), do: ""

    # No-op when the date is already in the requested
    # calendar; convert otherwise. `:calendrical` is a hard
    # dep of this library, so no runtime `ensure_loaded?`
    # check is needed.
    defp ensure_calendar(%Date{calendar: Calendar.ISO} = date, :gregorian), do: date

    defp ensure_calendar(%Date{} = date, cldr_calendar) when is_atom(cldr_calendar) do
      case Calendrical.calendar_from_cldr_calendar_type(cldr_calendar) do
        {:ok, module} when date.calendar == module ->
          date

        {:ok, module} ->
          case Date.convert(date, module) do
            {:ok, converted} -> converted
            _ -> date
          end

        _ ->
          date
      end
    end

    defp ensure_calendar(date, _), do: date

    defp date_attr(nil), do: nil
    defp date_attr(%Date{} = d), do: Date.to_iso8601(d)
    defp date_attr(string) when is_binary(string), do: string
    defp date_attr(_), do: nil

    defp iso_attr(explicit, _field_value) when is_binary(explicit) and explicit != "",
      do: explicit

    defp iso_attr(%Date{} = d, _field_value), do: Date.to_iso8601(d)
    defp iso_attr(_explicit, %Date{} = d), do: Date.to_iso8601(d)
    defp iso_attr(_explicit, string) when is_binary(string) and string != "", do: string
    defp iso_attr(_, _), do: ""

    # Map a CLDR calendar key (the `Localize.Calendar` /
    # `Calendrical` convention) to the corresponding BCP-47
    # `Intl.DateTimeFormat` calendar identifier so the JS
    # hook's `Intl.DateTimeFormat({ calendar: ... })` call
    # produces correctly-labelled month/year strings. Only
    # the identifiers Intl recognises are returned; anything
    # else falls through to "gregory" (the Intl default).
    @intl_calendar_map %{
      gregorian: "gregory",
      buddhist: "buddhist",
      chinese: "chinese",
      coptic: "coptic",
      dangi: "dangi",
      ethiopic: "ethiopic",
      ethiopic_amete_alem: "ethioaa",
      hebrew: "hebrew",
      indian: "indian",
      islamic: "islamic",
      islamic_civil: "islamic-civil",
      islamic_rgsa: "islamic-rgsa",
      islamic_tbla: "islamic-tbla",
      islamic_umalqura: "islamic-umalqura",
      japanese: "japanese",
      persian: "persian",
      roc: "roc"
    }

    defp cldr_to_intl_calendar(atom) when is_atom(atom),
      do: Map.get(@intl_calendar_map, atom, "gregory")
  end
end
