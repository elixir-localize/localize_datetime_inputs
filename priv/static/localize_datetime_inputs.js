// Localize.DateTimeInputs Phoenix LiveView hooks.
//
// Exports:
//
//   DatePicker        — single-date popup calendar
//   DateRangePicker   — two-date popup calendar
//
// Both hooks use the host browser's Intl.DateTimeFormat for
// locale-aware rendering of the calendar grid. No JS peer
// dependencies.

// ── DatePicker hook ─────────────────────────────────────────
//
// Renders a Gregorian month grid in an overlay anchored to a
// trigger button. Day clicks set both the visible text input
// (formatted via Intl.DateTimeFormat) and a hidden ISO input
// (the wire format).
//
// Data attributes read from the wrapper:
//   data-locale          BCP-47 locale (e.g. "en-GB")
//   data-display-format  Intl.DateTimeFormat option key,
//                        one of: short | medium | long | full
//                        (default: medium)
//   data-first-day       1..7 with 1=Monday, 7=Sunday
//                        (default derived from locale).
//   data-min             ISO date — earliest selectable day
//   data-max             ISO date — latest selectable day
//   data-variant         "auto" | "dropdown" | "sheet"
//
// Wire format on the hidden input is always ISO YYYY-MM-DD.

const DATE_PICKER_SHEET_BREAKPOINT_PX = 600;

function parseIsoDate(value) {
  if (!value) return null;
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!m) return null;
  const [_, y, mo, d] = m;
  const date = new Date(Date.UTC(Number(y), Number(mo) - 1, Number(d)));
  if (
    date.getUTCFullYear() !== Number(y) ||
    date.getUTCMonth() !== Number(mo) - 1 ||
    date.getUTCDate() !== Number(d)
  ) {
    return null;
  }
  return date;
}

function toIsoDate(date) {
  const y = date.getUTCFullYear();
  const mo = String(date.getUTCMonth() + 1).padStart(2, "0");
  const d = String(date.getUTCDate()).padStart(2, "0");
  return `${y}-${mo}-${d}`;
}

// Intl.Locale.prototype.weekInfo is Stage 3 and supported in
// modern engines. Fall back to Monday-first if unavailable.
function firstDayForLocale(localeTag) {
  try {
    const locale = new Intl.Locale(localeTag);
    const info = locale.weekInfo || locale.getWeekInfo?.();
    if (info && info.firstDay) return info.firstDay;
  } catch (_) {}
  return 1;
}

export const DatePicker = {
  mounted() {
    this.locale = this.el.dataset.locale || "en";
    this.displayFormat = this.el.dataset.displayFormat || "medium";
    // BCP-47 Intl calendar identifier (e.g. "gregory",
    // "buddhist", "japanese"). For "offset" calendars like
    // Buddhist/Japanese/ROC the grid structure is still
    // Gregorian — only month/year *labels* shift. For truly
    // different calendars (Hebrew, Islamic, Chinese, …) the
    // labels also localise via Intl, but the grid cell
    // boundaries remain Gregorian (a v2 enhancement).
    this.calendar = this.el.dataset.calendar || "gregory";

    const explicitFirstDay = Number(this.el.dataset.firstDay);
    this.firstDay = explicitFirstDay >= 1 && explicitFirstDay <= 7
      ? explicitFirstDay
      : firstDayForLocale(this.locale);

    this.min = parseIsoDate(this.el.dataset.min || "");
    this.max = parseIsoDate(this.el.dataset.max || "");
    this.variant = this.el.dataset.variant || "auto";

    this.textInput = this.el.querySelector("input.date-input-field");
    this.hiddenInput = this.el.querySelector("[data-date-picker-value]");
    this.trigger = this.el.querySelector("[data-date-picker-trigger]");
    this.overlay = this.el.querySelector("[data-date-picker-overlay]");
    this.grid = this.el.querySelector("[data-date-picker-grid]");
    this.monthLabel = this.el.querySelector("[data-date-picker-month-label]");
    this.prevButton = this.el.querySelector("[data-date-picker-prev]");
    this.nextButton = this.el.querySelector("[data-date-picker-next]");
    this.closeButton = this.el.querySelector("[data-date-picker-close]");

    // Initial cursor — what month is shown when the overlay
    // opens. Prefer the currently-selected date; fall back to
    // today.
    this.cursor = parseIsoDate(this.hiddenInput?.value || "") || new Date(
      Date.UTC(
        new Date().getUTCFullYear(),
        new Date().getUTCMonth(),
        1
      )
    );

    // Clicking the trigger TOGGLES the overlay. Clicking
    // outside the wrapper closes it. The explicit close (×)
    // button also closes.
    this.onTriggerClick = (e) => {
      e.preventDefault();
      e.stopPropagation();
      if (this.overlay && !this.overlay.hidden) {
        this.close();
      } else {
        this.open();
      }
    };
    this.onCloseClick = (e) => {
      e?.preventDefault();
      e?.stopPropagation();
      this.close();
    };
    this.onPrevClick = (e) => { e.preventDefault(); this.shiftMonth(-1); };
    this.onNextClick = (e) => { e.preventDefault(); this.shiftMonth(1); };
    this.onGridClick = (e) => {
      const cell = e.target.closest("[data-date-iso]");
      if (!cell || cell.hasAttribute("data-out-of-range")) return;
      e.stopPropagation();
      e.preventDefault();
      this.selectDay(cell.dataset.dateIso);
    };
    this.onKeydown = (e) => this.handleKeydown(e);
    this.onDocClick = (e) => {
      if (!this.el.contains(e.target)) this.close();
    };
    this.onTextChange = () => this.syncFromText();

    // Middle-ground focus ergonomics:
    //
    // * Click on the (empty) text input opens the popover —
    //   matches the user expectation that "interacting with
    //   the field" surfaces help. If the field already has
    //   a value, the click is treated as edit-intent and the
    //   popover stays closed.
    //
    // * Focus moving entirely outside the wrapper closes the
    //   popover — React Aria's pattern. `focusout`'s
    //   `relatedTarget` tells us where focus is going; if it
    //   lands inside the wrapper (the grid, a nav button)
    //   we don't close.
    this.onTextClick = () => {
      if (this.textInput && this.textInput.value === "") {
        this.open();
      }
    };
    this.onWrapperFocusOut = (e) => {
      const next = e.relatedTarget;
      if (!next || !this.el.contains(next)) {
        this.close({ refocus: false });
      }
    };

    this.trigger.addEventListener("click", this.onTriggerClick);
    this.closeButton?.addEventListener("click", this.onCloseClick);
    this.prevButton?.addEventListener("click", this.onPrevClick);
    this.nextButton?.addEventListener("click", this.onNextClick);
    this.grid?.addEventListener("click", this.onGridClick);
    this.el.addEventListener("keydown", this.onKeydown);
    this.textInput?.addEventListener("change", this.onTextChange);
    this.textInput?.addEventListener("blur", this.onTextChange);
    this.textInput?.addEventListener("click", this.onTextClick);
    this.el.addEventListener("focusout", this.onWrapperFocusOut);

    this.applySheetVariant();
    this.render();
  },

  destroyed() {
    this.trigger.removeEventListener("click", this.onTriggerClick);
    this.closeButton?.removeEventListener("click", this.onCloseClick);
    this.prevButton?.removeEventListener("click", this.onPrevClick);
    this.nextButton?.removeEventListener("click", this.onNextClick);
    this.grid?.removeEventListener("click", this.onGridClick);
    this.el.removeEventListener("keydown", this.onKeydown);
    this.textInput?.removeEventListener("change", this.onTextChange);
    this.textInput?.removeEventListener("blur", this.onTextChange);
    this.textInput?.removeEventListener("click", this.onTextClick);
    this.el.removeEventListener("focusout", this.onWrapperFocusOut);
    document.removeEventListener("click", this.onDocClick);
  },

  applySheetVariant() {
    const useSheet =
      this.variant === "sheet" ||
      (this.variant === "auto" &&
        window.matchMedia(`(max-width: ${DATE_PICKER_SHEET_BREAKPOINT_PX}px)`).matches);
    this.el.classList.toggle("is-sheet", useSheet);
  },

  open() {
    // Close any other open date/range picker overlay on the
    // page before showing this one. Without this, paired
    // pickers in `<.date_range_input>` cheerfully open
    // simultaneously and their popovers visually overlap.
    closeOtherDatePickers(this.el);

    this.overlay.hidden = false;
    this.trigger.setAttribute("aria-expanded", "true");
    this.applySheetVariant();
    if (!this.el.classList.contains("is-sheet")) {
      this.positionOverlay();
      this.repositionHandler = () => this.positionOverlay();
      window.addEventListener("resize", this.repositionHandler);
      window.addEventListener("scroll", this.repositionHandler, true);
    }
    setTimeout(() => {
      document.addEventListener("click", this.onDocClick);
    }, 0);
    this.render();
    // Move focus into the grid so arrow keys work right away.
    const focusable = this.grid?.querySelector('[tabindex="0"]');
    focusable?.focus();
  },

  close({ refocus = true } = {}) {
    this.overlay.hidden = true;
    this.trigger.setAttribute("aria-expanded", "false");
    document.removeEventListener("click", this.onDocClick);
    if (this.repositionHandler) {
      window.removeEventListener("resize", this.repositionHandler);
      window.removeEventListener("scroll", this.repositionHandler, true);
      this.repositionHandler = null;
    }
    this.overlay.style.position = "";
    this.overlay.style.top = "";
    this.overlay.style.left = "";
    this.overlay.style.width = "";
    if (refocus) this.trigger.focus();
  },

  positionOverlay() {
    const rect = this.trigger.getBoundingClientRect();
    const width = Math.max(rect.width, 280);
    const maxLeft = Math.max(8, window.innerWidth - width - 8);
    this.overlay.style.position = "fixed";
    this.overlay.style.top = `${rect.bottom + 4}px`;
    const preferred = rect.right - width;
    this.overlay.style.left = `${Math.max(8, Math.min(preferred, maxLeft))}px`;
    this.overlay.style.width = `${width}px`;
  },

  shiftMonth(delta) {
    const next = new Date(this.cursor.getTime());
    next.setUTCDate(1);
    next.setUTCMonth(next.getUTCMonth() + delta);
    this.cursor = next;
    this.render();
  },

  selectedDate() {
    return parseIsoDate(this.hiddenInput?.value || "");
  },

  selectDay(iso) {
    if (this.hiddenInput) {
      this.hiddenInput.value = iso;
      this.hiddenInput.dispatchEvent(new Event("change", { bubbles: true }));
    }
    if (this.textInput) {
      this.textInput.value = this.formatForDisplay(parseIsoDate(iso));
      this.textInput.dispatchEvent(new Event("change", { bubbles: true }));
    }
    this.cursor = parseIsoDate(iso);
    this.close({ refocus: false });
    this.textInput?.focus();
    this.el.dispatchEvent(
      new CustomEvent("localize-inputs:date-change", {
        detail: { date: iso },
        bubbles: true,
      })
    );
  },

  formatForDisplay(date) {
    if (!date) return "";
    try {
      return new Intl.DateTimeFormat(this.locale, {
        dateStyle: this.displayFormat,
        calendar: this.calendar,
      }).format(date);
    } catch (_) {
      return toIsoDate(date);
    }
  },

  syncFromText() {
    // On change/blur, if the text input value is a recognisable
    // ISO date, mirror it into the hidden input. Locale-aware
    // parsing happens server-side via Localize.Inputs.Parser.
    // For client-side cursor preservation we only fast-track
    // ISO.
    const value = this.textInput?.value || "";
    const date = parseIsoDate(value);
    if (date && this.hiddenInput) {
      this.hiddenInput.value = toIsoDate(date);
      this.cursor = date;
      this.render();
    }
  },

  render() {
    if (!this.grid) return;

    // Update month label.
    const year = this.cursor.getUTCFullYear();
    const month = this.cursor.getUTCMonth();
    const monthName = new Intl.DateTimeFormat(this.locale, {
      month: "long",
      year: "numeric",
      calendar: this.calendar,
    }).format(this.cursor);
    if (this.monthLabel) this.monthLabel.textContent = monthName;

    // Compute the first cell to render: scroll back to the first
    // day-of-week of the locale before/on the 1st of the month.
    const firstOfMonth = new Date(Date.UTC(year, month, 1));
    const dayOfWeek = ((firstOfMonth.getUTCDay() + 6) % 7) + 1; // 1=Mon..7=Sun
    const offset = (dayOfWeek - this.firstDay + 7) % 7;
    const gridStart = new Date(firstOfMonth.getTime());
    gridStart.setUTCDate(1 - offset);

    const selected = this.selectedDate();
    const today = new Date();
    const todayIso = toIsoDate(new Date(Date.UTC(today.getFullYear(), today.getMonth(), today.getDate())));

    // 42 cells = 6 weeks × 7 days — fits every month.
    const cells = [];
    for (let i = 0; i < 42; i++) {
      const cellDate = new Date(gridStart.getTime());
      cellDate.setUTCDate(gridStart.getUTCDate() + i);
      const iso = toIsoDate(cellDate);
      const inMonth = cellDate.getUTCMonth() === month;
      const isSelected = selected && toIsoDate(selected) === iso;
      const isToday = todayIso === iso;
      const outOfRange =
        (this.min && cellDate < this.min) || (this.max && cellDate > this.max);
      cells.push({
        iso,
        day: cellDate.getUTCDate(),
        inMonth,
        isSelected,
        isToday,
        outOfRange,
      });
    }

    // Render day-of-week header (use weekday names from Intl).
    // Day-of-week is calendar-independent (always 7 days,
    // Mon..Sun) so we don't pass `calendar:` here.
    const weekdayFormatter = new Intl.DateTimeFormat(this.locale, { weekday: "narrow" });
    const weekdayNames = [];
    // Pick a known week (Jan 4 2026 is a Sunday in UTC) and walk
    // 7 days starting from the locale's firstDay.
    const refMonday = new Date(Date.UTC(2026, 0, 5)); // Monday
    for (let i = 0; i < 7; i++) {
      const day = new Date(refMonday.getTime());
      day.setUTCDate(refMonday.getUTCDate() + ((this.firstDay - 1 + i) % 7));
      weekdayNames.push(weekdayFormatter.format(day));
    }

    // Day-number formatter — honours the calendar's preferred
    // digit system (e.g. Buddhist locale `th-TH` displays
    // Thai digits, Arabic locale `ar-SA` displays
    // Arabic-Indic digits).
    const dayFormatter = new Intl.DateTimeFormat(this.locale, {
      day: "numeric",
      calendar: this.calendar,
    });

    // Pick a single cell to carry tabindex=0 — the "roving
    // tabindex" pattern. Priority: selected day in visible
    // month → today in visible month → 1st of month.
    const visibleMonthYear = `${year}-${String(month + 1).padStart(2, "0")}`;
    let tabbableIso = null;
    if (selected && toIsoDate(selected).startsWith(visibleMonthYear)) {
      tabbableIso = toIsoDate(selected);
    } else if (todayIso.startsWith(visibleMonthYear)) {
      tabbableIso = todayIso;
    } else {
      tabbableIso = `${visibleMonthYear}-01`;
    }

    let html = "";
    html += `<thead><tr>`;
    for (const name of weekdayNames) {
      html += `<th scope="col">${escapeHtml(name)}</th>`;
    }
    html += `</tr></thead><tbody>`;
    for (let week = 0; week < 6; week++) {
      html += `<tr>`;
      for (let dow = 0; dow < 7; dow++) {
        const cell = cells[week * 7 + dow];
        const classes = ["date-picker-cell"];
        if (!cell.inMonth) classes.push("is-out-of-month");
        if (cell.isSelected) classes.push("is-selected");
        if (cell.isToday) classes.push("is-today");
        if (cell.outOfRange) classes.push("is-disabled");
        const outAttr = cell.outOfRange ? ' data-out-of-range="true" aria-disabled="true"' : "";
        const selAttr = cell.isSelected ? ' aria-selected="true"' : "";
        const tabAttr = cell.iso === tabbableIso ? ' tabindex="0"' : ' tabindex="-1"';
        const dayLabel = dayFormatter.format(parseIsoDate(cell.iso));
        html += `<td role="gridcell"><button type="button" class="${classes.join(" ")}" data-date-iso="${cell.iso}"${outAttr}${selAttr}${tabAttr}>${escapeHtml(dayLabel)}</button></td>`;
      }
      html += `</tr>`;
    }
    html += `</tbody>`;

    this.grid.innerHTML = html;
  },

  handleKeydown(e) {
    if (e.key === "Escape" && !this.overlay.hidden) {
      e.preventDefault();
      this.close();
      return;
    }
    if (this.overlay.hidden) return;

    // Arrow keys, Home/End, PgUp/PgDn navigate the grid.
    // Operate on a "focus cursor" — the day the user is
    // currently arrow-keying over, separate from the selected
    // day. The cursor is what `tabindex=0` is applied to so
    // screen readers announce it.
    const movements = {
      ArrowLeft: -1,
      ArrowRight: 1,
      ArrowUp: -7,
      ArrowDown: 7,
      Home: "week-start",
      End: "week-end",
      PageUp: e.shiftKey ? "prev-year" : "prev-month",
      PageDown: e.shiftKey ? "next-year" : "next-month",
    };

    if (e.key in movements) {
      e.preventDefault();
      this.moveCursor(movements[e.key]);
      return;
    }

    if (e.key === "Enter" || e.key === " ") {
      const focused = document.activeElement;
      if (focused && focused.dataset && focused.dataset.dateIso) {
        e.preventDefault();
        if (!focused.hasAttribute("data-out-of-range")) {
          this.selectDay(focused.dataset.dateIso);
        }
      }
    }
  },

  // Move the keyboard-focus cursor by the given action.
  // Numeric deltas are day counts (positive = forward).
  // String actions are week/month/year jumps.
  moveCursor(action) {
    // Anchor: whichever day currently has DOM focus inside
    // the grid, falling back to today or the 1st of the
    // visible month.
    let anchor = this.cursorDate();

    let next = new Date(anchor.getTime());
    if (typeof action === "number") {
      next.setUTCDate(anchor.getUTCDate() + action);
    } else if (action === "week-start") {
      const dow = ((anchor.getUTCDay() + 6) % 7) + 1; // 1=Mon..7=Sun
      const offset = (dow - this.firstDay + 7) % 7;
      next.setUTCDate(anchor.getUTCDate() - offset);
    } else if (action === "week-end") {
      const dow = ((anchor.getUTCDay() + 6) % 7) + 1;
      const offset = (dow - this.firstDay + 7) % 7;
      next.setUTCDate(anchor.getUTCDate() + (6 - offset));
    } else if (action === "prev-month") {
      next.setUTCMonth(anchor.getUTCMonth() - 1);
    } else if (action === "next-month") {
      next.setUTCMonth(anchor.getUTCMonth() + 1);
    } else if (action === "prev-year") {
      next.setUTCFullYear(anchor.getUTCFullYear() - 1);
    } else if (action === "next-year") {
      next.setUTCFullYear(anchor.getUTCFullYear() + 1);
    }

    // Skip across the month boundary if the cursor moved out
    // of the visible month.
    const cursorMonth = this.cursor.getUTCMonth();
    const cursorYear = this.cursor.getUTCFullYear();
    if (
      next.getUTCMonth() !== cursorMonth ||
      next.getUTCFullYear() !== cursorYear
    ) {
      this.cursor = new Date(
        Date.UTC(next.getUTCFullYear(), next.getUTCMonth(), 1)
      );
      this.render();
    }

    // Focus the corresponding cell in the (possibly new) grid.
    const iso = toIsoDate(next);
    const cell = this.grid?.querySelector(`[data-date-iso="${iso}"]`);
    if (cell) cell.focus();
  },

  // Resolve the day to use as a movement anchor. Priority:
  // currently-focused cell → selected date → today (if in
  // visible month) → 1st of visible month.
  cursorDate() {
    const focused = document.activeElement;
    if (focused && focused.dataset && focused.dataset.dateIso) {
      const d = parseIsoDate(focused.dataset.dateIso);
      if (d) return d;
    }
    const selected = this.selectedDate();
    if (
      selected &&
      selected.getUTCMonth() === this.cursor.getUTCMonth() &&
      selected.getUTCFullYear() === this.cursor.getUTCFullYear()
    ) {
      return selected;
    }
    return new Date(
      Date.UTC(
        this.cursor.getUTCFullYear(),
        this.cursor.getUTCMonth(),
        1
      )
    );
  },
};

// ── RangePicker hook ────────────────────────────────────────
//
// Reuses DatePicker's grid rendering but switches to two-click
// selection: the first click sets the range start, the second
// click sets the end. Hovering over cells between the two
// highlights the in-progress range.
//
// Wire format:
//   - hidden input "from" (data-range-picker-from): ISO start
//   - hidden input "to"   (data-range-picker-to):   ISO end
//
// Visible text inputs (`input.range-from-field` and
// `input.range-to-field`) reflect locale-formatted display
// values. Both populate on each selection (which may close the
// popover when both ends are set).

export const RangePicker = {
  ...DatePicker,

  mounted() {
    DatePicker.mounted.call(this);

    // RangePicker-specific elements.
    this.fromInput = this.el.querySelector("input.range-from-field");
    this.toInput = this.el.querySelector("input.range-to-field");
    this.fromHidden = this.el.querySelector("[data-range-picker-from]");
    this.toHidden = this.el.querySelector("[data-range-picker-to]");

    // Selection state. `pendingStart` carries the first click;
    // when the second click lands we commit both ends.
    this.pendingStart = null;

    // Hover preview during pending-start phase.
    this.onGridMouseover = (e) => {
      if (!this.pendingStart) return;
      const cell = e.target.closest("[data-date-iso]");
      if (!cell) return;
      this.previewRange(this.pendingStart, cell.dataset.dateIso);
    };

    this.grid?.addEventListener("mouseover", this.onGridMouseover);
  },

  destroyed() {
    this.grid?.removeEventListener("mouseover", this.onGridMouseover);
    DatePicker.destroyed.call(this);
  },

  selectedDate() {
    // Used by DatePicker.render() to highlight the "selected"
    // cell. For range mode, return the currently-committed
    // start so the rendered grid shows it.
    return parseIsoDate(this.fromHidden?.value || "");
  },

  // Override DatePicker.selectDay — three-state range
  // selection. State A (neither end set): first click arms
  // the range. State B (only start set, end pending): second
  // click commits the end. State C (both ends already
  // committed): treat the click as resetting to State B —
  // start a fresh range at the clicked day.
  selectDay(iso) {
    const hasCommittedRange =
      this.fromHidden?.value &&
      this.toHidden?.value &&
      !this.pendingStart;

    if (hasCommittedRange) {
      // State C: third click after a finished range starts a
      // new range. Wipe the old range so the user gets
      // unambiguous feedback that they've started over.
      this.pendingStart = iso;
      this.commitFrom(iso);
      this.commitTo("");
      this.previewRange(iso, iso);
      return;
    }

    if (!this.pendingStart) {
      // State A: arm the range.
      this.pendingStart = iso;
      this.commitFrom(iso);
      this.commitTo("");
      this.previewRange(iso, iso);
      return;
    }

    // State B: second click. Order by date so from <= to.
    const [from, to] =
      iso < this.pendingStart
        ? [iso, this.pendingStart]
        : [this.pendingStart, iso];

    this.commitFrom(from);
    this.commitTo(to);
    this.pendingStart = null;
    this.clearPreview();
    this.cursor = parseIsoDate(to);
    this.close({ refocus: false });
    this.el.dispatchEvent(
      new CustomEvent("localize-inputs:range-change", {
        detail: { from, to },
        bubbles: true,
      })
    );
  },

  commitFrom(iso) {
    if (this.fromHidden) {
      this.fromHidden.value = iso;
      this.fromHidden.dispatchEvent(new Event("change", { bubbles: true }));
    }
    if (this.fromInput) {
      this.fromInput.value = iso ? this.formatForDisplay(parseIsoDate(iso)) : "";
      this.fromInput.dispatchEvent(new Event("change", { bubbles: true }));
    }
  },

  commitTo(iso) {
    if (this.toHidden) {
      this.toHidden.value = iso;
      this.toHidden.dispatchEvent(new Event("change", { bubbles: true }));
    }
    if (this.toInput) {
      this.toInput.value = iso ? this.formatForDisplay(parseIsoDate(iso)) : "";
      this.toInput.dispatchEvent(new Event("change", { bubbles: true }));
    }
  },

  // Visually highlight in-progress range during second-click
  // hover. Re-rendering the whole grid on every mousemove
  // would be wasteful — instead we walk the cells and toggle
  // CSS classes.
  previewRange(fromIso, toIso) {
    const from = fromIso < toIso ? fromIso : toIso;
    const to = fromIso < toIso ? toIso : fromIso;
    if (!this.grid) return;

    this.grid.querySelectorAll("[data-date-iso]").forEach((cell) => {
      const iso = cell.dataset.dateIso;
      cell.classList.toggle("is-range-end", iso === fromIso || iso === toIso);
      cell.classList.toggle(
        "is-in-range",
        iso > from && iso < to
      );
    });
  },

  clearPreview() {
    if (!this.grid) return;
    this.grid.querySelectorAll("[data-date-iso]").forEach((cell) => {
      cell.classList.remove("is-range-end", "is-in-range");
    });
  },

  // After DatePicker.render() rewrites the grid, re-apply any
  // pending range highlight.
  render() {
    DatePicker.render.call(this);
    const from = this.fromHidden?.value;
    const to = this.toHidden?.value;
    if (from && to) {
      this.previewRange(from, to);
    } else if (this.pendingStart) {
      this.previewRange(this.pendingStart, this.pendingStart);
    }
  },
};

// Find every other open date-picker overlay on the page and
// close it. Called from each picker's open() so paired pickers
// in a date_range_input or sibling instances on the same form
// don't end up with two popovers visible at once (their CSS
// overlap is also a problem; the right answer is one picker
// open at a time).
function closeOtherDatePickers(currentWrapper) {
  document.querySelectorAll("[data-date-input]").forEach((wrapper) => {
    if (wrapper === currentWrapper) return;
    const overlay = wrapper.querySelector("[data-date-picker-overlay]");
    if (overlay && !overlay.hidden) {
      overlay.hidden = true;
      const trigger = wrapper.querySelector("[data-date-picker-trigger]");
      trigger?.setAttribute("aria-expanded", "false");
    }
  });
}

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}


export default { DatePicker, RangePicker };
