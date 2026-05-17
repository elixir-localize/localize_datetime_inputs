if Code.ensure_loaded?(Phoenix.LiveComponent) and
     Code.ensure_loaded?(Gettext.Backend) do
  defmodule Localize.Inputs.Date.Components.DatePickerLive do
    @moduledoc """
    Server-rendered date picker LiveComponent with full
    multi-calendar grid support.

    Where `<.date_input>` ships a Gregorian-structured grid
    re-labelled via `Intl.DateTimeFormat`, this component
    renders the grid **in the configured calendar's own
    month structure** — Hebrew months span Hebrew month
    boundaries, Islamic months wrap at the Islamic month
    end, Persian Esfand has 29 or 30 days depending on the
    33-year cycle, and so on. Calendar arithmetic delegates
    to the Calendrical Calendar behaviour module (`Date.add/2`,
    `Date.day_of_week/1`, `Date.days_in_month/1`).

    Wire format on the form is the same as `<.date_input>`:
    ISO-8601 (`YYYY-MM-DD`, Gregorian) via the embedded hidden
    input. Server-side, parse with
    `Localize.Inputs.Date.Parser.parse_date/2` or just read
    `params[field]` directly.

    ## Usage

        <.live_component
          module={Localize.Inputs.Date.Components.DatePickerLive}
          id="event-date"
          form={@form}
          field={:date}
          calendar={:hebrew}
          locale={:"he-IL"}
        />

    ## Attributes

    * `:id` — required, unique per LiveComponent instance.

    * `:form` — the `Phoenix.HTML.Form` the field belongs to.

    * `:field` — the form field as an atom.

    * `:calendar` — a CLDR calendar key (`:gregorian`,
      `:hebrew`, `:islamic_civil`, `:islamic_umalqura`,
      `:persian`, `:japanese`, `:buddhist`, `:roc`, etc.).
      Defaults to `:gregorian`.

    * `:locale` — display locale. Defaults to
      `Localize.get_locale/0`.

    * `:min`, `:max` — bounds as ISO strings or `Date`
      structs. Cells outside the bounds render as
      disabled.

    * `:display_format` — one of `:short`, `:medium`
      (default), `:long`, `:full`. Controls the visible
      text-input formatting (the wire value is always ISO).

    * `:class`, `:input_class`, `:button_class`,
      `:overlay_class` — customisation hooks.

    """

    use Phoenix.LiveComponent
    use Localize.Message.Sigils, backend: Localize.Inputs.Gettext

    @impl true
    def mount(socket) do
      {:ok, assign(socket, open: false)}
    end

    @impl true
    def update(assigns, socket) do
      cldr_calendar = Map.get(assigns, :calendar, :gregorian)
      locale = Map.get(assigns, :locale) || Localize.get_locale()
      calendar_module = resolve_calendar_module(cldr_calendar)
      field_struct = assigns.form[assigns.field]

      iso_value =
        case field_struct.value do
          %Date{} = d -> Date.to_iso8601(d)
          s when is_binary(s) and s != "" -> s
          _ -> nil
        end

      selected_iso_date =
        case iso_value && Date.from_iso8601(iso_value) do
          {:ok, d} -> d
          _ -> nil
        end

      cursor = derive_cursor(socket.assigns, selected_iso_date, calendar_module)

      socket =
        socket
        |> assign(assigns)
        |> assign(:cldr_calendar, cldr_calendar)
        |> assign(:locale, locale)
        |> assign(:calendar_module, calendar_module)
        |> assign(:field_struct, field_struct)
        |> assign(:iso_value, iso_value || "")
        |> assign(:selected_iso_date, selected_iso_date)
        |> assign(:cursor, cursor)
        |> assign(
          :formatted_value,
          format_for_display(selected_iso_date, locale, calendar_module, assigns)
        )
        |> assign_new(:display_format, fn -> :medium end)
        |> assign_new(:min, fn -> nil end)
        |> assign_new(:max, fn -> nil end)
        |> assign_new(:placeholder, fn -> nil end)
        |> assign_new(:class, fn -> nil end)
        |> assign_new(:input_class, fn -> nil end)
        |> assign_new(:button_class, fn -> nil end)
        |> assign_new(:overlay_class, fn -> nil end)

      {:ok, socket}
    end

    @impl true
    def handle_event("toggle", _params, socket) do
      {:noreply, assign(socket, open: !socket.assigns.open)}
    end

    def handle_event("close", _params, socket) do
      {:noreply, assign(socket, open: false)}
    end

    def handle_event("prev_month", _params, socket) do
      {:noreply, assign(socket, cursor: shift_cursor(socket.assigns.cursor, -1))}
    end

    def handle_event("next_month", _params, socket) do
      {:noreply, assign(socket, cursor: shift_cursor(socket.assigns.cursor, 1))}
    end

    def handle_event("select_day", %{"iso" => iso}, socket) do
      case Date.from_iso8601(iso) do
        {:ok, date} ->
          calendar = socket.assigns.calendar_module

          calendar_date = safe_convert(date, calendar)

          {:noreply,
           socket
           |> assign(:selected_iso_date, date)
           |> assign(:iso_value, iso)
           |> assign(:cursor, %{year: calendar_date.year, month: calendar_date.month})
           |> assign(
             :formatted_value,
             format_for_display(date, socket.assigns.locale, calendar, socket.assigns)
           )
           |> assign(:open, false)}

        _ ->
          {:noreply, socket}
      end
    end

    @impl true
    def render(assigns) do
      assigns = assign(assigns, :grid, build_grid(assigns))

      ~H"""
      <div class={["date-input-wrapper", "date-picker-live", @class]} id={@id} data-date-input>
        <input
          type="text"
          name={@field_struct.name}
          id={"#{@id}-text"}
          value={@formatted_value}
          class={["date-input-field", @input_class]}
          autocomplete="off"
          placeholder={@placeholder}
          readonly
        />
        <input type="hidden" id={"#{@id}-iso"} value={@iso_value} />
        <button
          type="button"
          class={["date-input-trigger", @button_class]}
          phx-click="toggle"
          phx-target={@myself}
          aria-haspopup="dialog"
          aria-expanded={to_string(@open)}
          aria-label={~t"Open calendar"}
        >
          <span aria-hidden="true">📅</span>
        </button>
        <div
          :if={@open}
          class={["date-picker-overlay", @overlay_class]}
          role="dialog"
          aria-label={~t"Choose date"}
        >
          <div class="date-picker-header">
            <button
              type="button"
              class="date-picker-nav"
              phx-click="prev_month"
              phx-target={@myself}
              aria-label={~t"Previous month"}
            >‹</button>
            <span class="date-picker-month-label">{@grid.month_label}</span>
            <button
              type="button"
              class="date-picker-nav"
              phx-click="next_month"
              phx-target={@myself}
              aria-label={~t"Next month"}
            >›</button>
            <button
              type="button"
              class="date-picker-close"
              phx-click="close"
              phx-target={@myself}
              aria-label={~t"Close calendar"}
            >×</button>
          </div>
          <table class="date-picker-grid" role="grid">
            <thead>
              <tr>
                <th :for={name <- @grid.weekday_names} scope="col">{name}</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={week <- @grid.weeks}>
                <td :for={cell <- week} role="gridcell">
                  <button
                    type="button"
                    class={[
                      "date-picker-cell",
                      not cell.in_month && "is-out-of-month",
                      cell.is_selected && "is-selected",
                      cell.is_today && "is-today",
                      cell.disabled && "is-disabled"
                    ]}
                    phx-click={if(not cell.disabled, do: "select_day")}
                    phx-value-iso={cell.iso}
                    phx-target={@myself}
                    aria-disabled={if(cell.disabled, do: "true")}
                    aria-selected={if(cell.is_selected, do: "true")}
                  >{cell.day_label}</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
      """
    end

    # ── Internals ──────────────────────────────────────────

    defp resolve_calendar_module(:gregorian), do: Calendar.ISO

    defp resolve_calendar_module(cldr_calendar) do
      # `:calendrical` is a hard dep of this library, so no
      # runtime `ensure_loaded?` check is needed.
      case Calendrical.calendar_from_cldr_calendar_type(cldr_calendar) do
        {:ok, module} -> module
        _ -> Calendar.ISO
      end
    end

    defp derive_cursor(prev_assigns, selected_iso_date, calendar_module) do
      cond do
        match?(%{cursor: %{year: _, month: _}}, prev_assigns) ->
          prev_assigns.cursor

        selected_iso_date ->
          calendar_date = safe_convert(selected_iso_date, calendar_module)
          %{year: calendar_date.year, month: calendar_date.month}

        true ->
          today_in_calendar = safe_convert(Date.utc_today(), calendar_module)
          %{year: today_in_calendar.year, month: today_in_calendar.month}
      end
    end

    defp shift_cursor(%{year: year, month: month}, delta) do
      total = year * 12 + (month - 1) + delta
      %{year: div(total, 12), month: rem(total, 12) + 1}
    end

    # Build a 6×7 grid for `cursor` in `calendar_module`.
    # Returns `%{month_label, weekday_names, weeks}` where each
    # cell is `%{iso, day_label, in_month, is_selected,
    # is_today, disabled}`.
    defp build_grid(assigns) do
      calendar = assigns.calendar_module
      cursor = assigns.cursor
      locale = assigns.locale

      first_of_month = safe_build_date(cursor.year, cursor.month, 1, calendar)
      first_dow = Date.day_of_week(first_of_month)
      first_day_of_week = first_day_for_locale(locale)
      offset = rem(first_dow - first_day_of_week + 7, 7)
      grid_start = Date.add(first_of_month, -offset)

      today_iso = today_iso()
      selected_iso = assigns[:iso_value]
      min_iso = to_iso_attr(assigns[:min])
      max_iso = to_iso_attr(assigns[:max])

      cells =
        Enum.map(0..41, fn i ->
          cell_date = Date.add(grid_start, i)

          iso_date = safe_convert(cell_date, Calendar.ISO)
          iso = Date.to_iso8601(iso_date)

          %{
            iso: iso,
            day_label: format_day(cell_date, locale),
            in_month: cell_date.month == cursor.month,
            is_selected: iso == selected_iso,
            is_today: iso == today_iso,
            disabled: out_of_range?(iso, min_iso, max_iso)
          }
        end)

      weeks =
        cells
        |> Enum.chunk_every(7)

      %{
        month_label: format_month_label(first_of_month, locale),
        weekday_names: build_weekday_names(first_day_of_week, locale),
        weeks: weeks
      }
    end

    # Library code never raises on render-path. If the
    # year/month/day combo isn't valid in `calendar`, fall
    # back to a known-good Gregorian today — the UI still
    # renders rather than 500ing.
    defp safe_build_date(year, month, day, Calendar.ISO) do
      case Date.new(year, month, day) do
        {:ok, d} -> d
        _ -> Date.utc_today()
      end
    end

    defp safe_build_date(year, month, day, module) do
      case Date.new(year, month, day, module) do
        {:ok, d} ->
          d

        _ ->
          # Fall back to today converted into the target
          # calendar; if that also fails, return ISO today.
          safe_convert(Date.utc_today(), module)
      end
    end

    # Tolerant `Date.convert`: returns the input untouched if
    # conversion fails (so callers always get back a valid
    # `%Date{}` for display arithmetic).
    defp safe_convert(%Date{calendar: target} = date, target), do: date

    defp safe_convert(%Date{} = date, target) do
      case Date.convert(date, target) do
        {:ok, converted} -> converted
        _ -> date
      end
    end

    defp first_day_for_locale(locale) do
      case Localize.Calendar.first_day_for_locale(locale) do
        n when is_integer(n) -> n
        _ -> 1
      end
    end

    defp build_weekday_names(first_day, locale) do
      # `Localize.Calendar.days/2` returns localized day names
      # keyed 1..7 (1=Monday). Rotate starting from
      # `first_day`.
      case Localize.Calendar.days(locale, :gregorian) do
        {:ok, data} ->
          narrow = get_in(data, [:format, :narrow]) || %{}

          for i <- 0..6 do
            day = rem(first_day - 1 + i, 7) + 1
            Map.get(narrow, day, "")
          end

        _ ->
          ["M", "T", "W", "T", "F", "S", "S"]
      end
    end

    defp format_month_label(%{year: _, month: _} = date, locale) do
      case Localize.Date.to_string(date, locale: locale, format: :yMMMM) do
        {:ok, formatted} -> formatted
        _ -> "#{date.year}-#{String.pad_leading(to_string(date.month), 2, "0")}"
      end
    end

    defp format_day(date, locale) do
      case Localize.Date.to_string(date, locale: locale, format: :d) do
        {:ok, formatted} -> formatted
        _ -> to_string(date.day)
      end
    end

    defp format_for_display(nil, _locale, _calendar_module, _assigns), do: ""

    defp format_for_display(%Date{} = date, locale, calendar_module, assigns) do
      format = Map.get(assigns, :display_format, :medium)

      # Convert the ISO Date into the display calendar before
      # formatting. `Localize.Date.to_string/2` reads
      # `date.calendar` and dispatches its CLDR pattern lookup
      # by that calendar — so a `Calendar.ISO` Date always
      # formats under `:gregorian` regardless of the
      # `:calendar` attr the component received. We convert
      # here so Japanese imperial / Buddhist / Hijri locales
      # render their own year and era markers.
      display_date = safe_convert(date, calendar_module)

      case Localize.Date.to_string(display_date, locale: locale, format: format) do
        {:ok, formatted} -> formatted
        _ -> Date.to_iso8601(date)
      end
    end

    defp today_iso, do: Date.to_iso8601(Date.utc_today())

    defp to_iso_attr(nil), do: nil
    defp to_iso_attr(%Date{} = d), do: Date.to_iso8601(d)
    defp to_iso_attr(s) when is_binary(s), do: s
    defp to_iso_attr(_), do: nil

    defp out_of_range?(_iso, nil, nil), do: false
    defp out_of_range?(iso, min, nil), do: iso < min
    defp out_of_range?(iso, nil, max), do: iso > max
    defp out_of_range?(iso, min, max), do: iso < min or iso > max
  end
end
