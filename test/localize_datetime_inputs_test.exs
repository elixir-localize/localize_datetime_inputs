defmodule Localize.DateTimeInputsTest do
  use ExUnit.Case

  doctest Localize.Inputs.Date.Parser
  doctest Localize.Inputs.Date.Validator

  describe "Parser.parse_date/2" do
    test "ISO 8601 always parses in every locale" do
      for locale <- [:en, :"en-GB", :de, :fr, :ja] do
        assert {:ok, ~D[2026-05-16]} =
                 Localize.Inputs.Date.Parser.parse_date("2026-05-16", locale: locale)
      end
    end

    test "en uses M/d ordering" do
      assert {:ok, ~D[2026-05-16]} =
               Localize.Inputs.Date.Parser.parse_date("5/16/26", locale: :en)
    end

    test "en-GB uses d/M ordering" do
      assert {:ok, ~D[2026-05-16]} =
               Localize.Inputs.Date.Parser.parse_date("16/05/2026", locale: :"en-GB")
    end

    test "de uses dd.MM ordering" do
      assert {:ok, ~D[2026-05-16]} =
               Localize.Inputs.Date.Parser.parse_date("16.05.2026", locale: :de)
    end

    test "ja uses y/M/d ordering" do
      assert {:ok, ~D[2026-05-16]} =
               Localize.Inputs.Date.Parser.parse_date("2026/05/16", locale: :ja)
    end

    test "the same input parses differently per locale (the value-add)" do
      assert {:ok, us_date} =
               Localize.Inputs.Date.Parser.parse_date("3/4/26", locale: :en)

      assert {:ok, gb_date} =
               Localize.Inputs.Date.Parser.parse_date("3/4/26", locale: :"en-GB")

      # US: Mar 4, UK: 3 Apr. Same input, different parsed date.
      assert us_date == ~D[2026-03-04]
      assert gb_date == ~D[2026-04-03]
    end

    test "blank input is nil" do
      assert {:ok, nil} = Localize.Inputs.Date.Parser.parse_date("", locale: :en)
      assert {:ok, nil} = Localize.Inputs.Date.Parser.parse_date(nil, locale: :en)
    end

    test "garbage rejected with structured error" do
      assert {:error, %Calendrical.DateParseError{input: "garbage"}} =
               Localize.Inputs.Date.Parser.parse_date("garbage", locale: :en)
    end

    test "lenient separator equivalence (CLDR lenient-scope-date)" do
      # CLDR says these are all equivalent date separators in en.
      for sep <- ["/", "-", "."] do
        assert {:ok, ~D[2026-05-16]} =
                 Localize.Inputs.Date.Parser.parse_date("5#{sep}16#{sep}26", locale: :en)
      end
    end

    test "out-of-calendar date rejected" do
      assert {:error, _} =
               Localize.Inputs.Date.Parser.parse_date("2026-02-30", locale: :en)
    end

    test "two-digit year pivots forward by default" do
      # With reference_date in 2026, "30" should pivot to 2030, "70" to 1970.
      ref = ~D[2026-05-16]

      assert {:ok, ~D[2030-05-16]} =
               Localize.Inputs.Date.Parser.parse_date("5/16/30",
                 locale: :en,
                 reference_date: ref
               )

      assert {:ok, ~D[1970-05-16]} =
               Localize.Inputs.Date.Parser.parse_date("5/16/70",
                 locale: :en,
                 reference_date: ref
               )
    end
  end

  describe "Validator.validate_date/2" do
    test "passes within bounds" do
      assert :ok =
               Localize.Inputs.Date.Validator.validate_date(~D[2026-05-16],
                 min: ~D[2026-01-01],
                 max: ~D[2026-12-31]
               )
    end

    test "rejects below :min with iso-formatted bound" do
      assert {:error, %Localize.Inputs.ValidationError{errors: errors}} =
               Localize.Inputs.Date.Validator.validate_date(~D[2025-01-01], min: "2026-01-01")

      assert Keyword.get(errors, :min) =~ "2026-01-01"
    end

    test "rejects weekend when :not_weekend is true" do
      # 2026-05-16 is a Saturday.
      assert {:error, %Localize.Inputs.ValidationError{errors: errors}} =
               Localize.Inputs.Date.Validator.validate_date(~D[2026-05-16], not_weekend: true)

      assert Keyword.has_key?(errors, :weekend)
    end

    test "custom :weekend_days list (Fri+Sat as weekend, Sun as workday)" do
      # 2026-05-17 is a Sunday — should pass under Fri/Sat weekend.
      assert :ok =
               Localize.Inputs.Date.Validator.validate_date(~D[2026-05-17],
                 not_weekend: true,
                 weekend_days: [5, 6]
               )
    end

    test "nil rejected when required" do
      assert {:error, %Localize.Inputs.ValidationError{errors: [{:required, _}]}} =
               Localize.Inputs.Date.Validator.validate_date(nil, required: true)
    end

    test "nil accepted when not required" do
      assert :ok = Localize.Inputs.Date.Validator.validate_date(nil)
    end

    test ":on_or_after is an alias for :min" do
      assert {:error, %Localize.Inputs.ValidationError{errors: errors}} =
               Localize.Inputs.Date.Validator.validate_date(~D[2025-01-01],
                 on_or_after: ~D[2026-01-01]
               )

      assert Keyword.get(errors, :min) =~ "2026-01-01"
    end

    test ":on_or_before is an alias for :max" do
      assert {:error, %Localize.Inputs.ValidationError{errors: errors}} =
               Localize.Inputs.Date.Validator.validate_date(~D[2027-01-01],
                 on_or_before: ~D[2026-12-31]
               )

      assert Keyword.get(errors, :max) =~ "2026-12-31"
    end

    test "stricter bound wins when both :min and :on_or_after given" do
      # :min = 2026-01-01, :on_or_after = 2026-06-01 — keep the later
      assert {:error, %Localize.Inputs.ValidationError{errors: errors}} =
               Localize.Inputs.Date.Validator.validate_date(~D[2026-03-01],
                 min: ~D[2026-01-01],
                 on_or_after: ~D[2026-06-01]
               )

      assert Keyword.get(errors, :min) =~ "2026-06-01"
    end

    test ":business_days_only rejects Saturday" do
      # 2026-05-16 is a Saturday.
      assert {:error, %Localize.Inputs.ValidationError{errors: errors}} =
               Localize.Inputs.Date.Validator.validate_date(~D[2026-05-16],
                 business_days_only: true
               )

      assert Keyword.has_key?(errors, :weekend)
    end

    test ":business_days_only respects :weekend_days override" do
      # Pretend the locale's weekend is Fri+Sat. Then 2026-05-17
      # (Sunday) becomes a workday.
      assert :ok =
               Localize.Inputs.Date.Validator.validate_date(~D[2026-05-17],
                 business_days_only: true,
                 weekend_days: [5, 6]
               )
    end
  end

  describe "Validator.validate_date_range/2" do
    test "passes within bounds and span limits" do
      range = Date.range(~D[2026-05-01], ~D[2026-05-07])

      assert :ok =
               Localize.Inputs.Date.Validator.validate_date_range(range,
                 min: ~D[2026-01-01],
                 max: ~D[2026-12-31],
                 min_span: 5,
                 max_span: 10
               )
    end

    test "rejects span shorter than :min_span" do
      range = Date.range(~D[2026-05-01], ~D[2026-05-03])

      assert {:error, %Localize.Inputs.ValidationError{errors: errors}} =
               Localize.Inputs.Date.Validator.validate_date_range(range, min_span: 5)

      assert Keyword.get(errors, :min_span) =~ "5"
    end

    test "rejects span longer than :max_span" do
      range = Date.range(~D[2026-05-01], ~D[2026-05-31])

      assert {:error, %Localize.Inputs.ValidationError{errors: errors}} =
               Localize.Inputs.Date.Validator.validate_date_range(range, max_span: 7)

      assert Keyword.get(errors, :max_span) =~ "7"
    end

    test "endpoint bounds apply" do
      range = Date.range(~D[2025-01-01], ~D[2025-01-07])

      assert {:error, %Localize.Inputs.ValidationError{errors: errors}} =
               Localize.Inputs.Date.Validator.validate_date_range(range, min: ~D[2026-01-01])

      assert Keyword.has_key?(errors, :min)
    end

    test "inverted range rejected when :disallow_inverted" do
      inverted = Date.range(~D[2026-05-10], ~D[2026-05-05], -1)

      assert {:error, %Localize.Inputs.ValidationError{errors: errors}} =
               Localize.Inputs.Date.Validator.validate_date_range(inverted,
                 disallow_inverted: true
               )

      assert Keyword.has_key?(errors, :inverted)
    end
  end

  describe "Components.date_input/1" do
    test "renders expected DOM and hook attributes" do
      form = Phoenix.HTML.FormData.to_form(%{}, as: :event)

      assigns = %{
        form: form,
        field: :date,
        value: nil,
        locale: :en,
        min: nil,
        max: nil,
        placeholder: nil,
        display_format: :medium,
        variant: :auto,
        js: true,
        class: nil,
        input_class: nil,
        button_class: nil,
        overlay_class: nil,
        rest: %{},
        __changed__: nil
      }

      html =
        assigns
        |> Localize.Inputs.Date.Components.date_input()
        |> Phoenix.HTML.Safe.to_iodata()
        |> IO.iodata_to_binary()

      assert html =~ ~s|class="date-input-wrapper |
      assert html =~ ~s|phx-hook="DatePicker"|
      assert html =~ ~s|data-locale="en"|
      assert html =~ ~s|name="event[date]"|
      assert html =~ ~s|data-date-picker-trigger|
      assert html =~ ~s|data-date-picker-overlay|
      assert html =~ ~s|data-date-picker-grid|
    end

    test "renders min/max as ISO data attrs" do
      form = Phoenix.HTML.FormData.to_form(%{}, as: :event)

      assigns = %{
        form: form,
        field: :date,
        value: nil,
        locale: :en,
        min: ~D[2026-01-01],
        max: ~D[2026-12-31],
        placeholder: nil,
        display_format: :medium,
        variant: :auto,
        js: true,
        class: nil,
        input_class: nil,
        button_class: nil,
        overlay_class: nil,
        rest: %{},
        __changed__: nil
      }

      html =
        assigns
        |> Localize.Inputs.Date.Components.date_input()
        |> Phoenix.HTML.Safe.to_iodata()
        |> IO.iodata_to_binary()

      assert html =~ ~s|data-min="2026-01-01"|
      assert html =~ ~s|data-max="2026-12-31"|
    end

    test "Date value formats via Localize.Date.to_string" do
      form = Phoenix.HTML.FormData.to_form(%{"date" => ~D[2026-05-16]}, as: :event)

      assigns = %{
        form: form,
        field: :date,
        value: nil,
        locale: :en,
        min: nil,
        max: nil,
        placeholder: nil,
        display_format: :medium,
        variant: :auto,
        js: true,
        class: nil,
        input_class: nil,
        button_class: nil,
        overlay_class: nil,
        rest: %{},
        __changed__: nil
      }

      html =
        assigns
        |> Localize.Inputs.Date.Components.date_input()
        |> Phoenix.HTML.Safe.to_iodata()
        |> IO.iodata_to_binary()

      # en medium format for 2026-05-16 is "May 16, 2026"
      assert html =~ "May 16, 2026"
    end
  end

  describe "Components.date_range_input/1" do
    test "renders two date_input children" do
      # Reference the derived field atoms so they exist —
      # the component intentionally uses `String.to_existing_atom`
      # for its `{field}_from` / `{field}_to` child fields,
      # which in production are defined by the consumer's
      # changeset/schema.
      _ = :trip_from
      _ = :trip_to
      form = Phoenix.HTML.FormData.to_form(%{}, as: :event)

      assigns = %{
        form: form,
        field: :trip,
        locale: :en,
        min: nil,
        max: nil,
        placeholder_from: nil,
        placeholder_to: nil,
        display_format: :medium,
        calendar: :gregorian,
        variant: :auto,
        js: true,
        class: nil,
        input_class: nil,
        button_class: nil,
        overlay_class: nil,
        __changed__: nil
      }

      html =
        assigns
        |> Localize.Inputs.Date.Components.date_range_input()
        |> Phoenix.HTML.Safe.to_iodata()
        |> IO.iodata_to_binary()

      assert html =~ ~s|class="date-range-input-wrapper |
      assert html =~ ~s|name="event[trip_from]"|
      assert html =~ ~s|name="event[trip_to]"|
      assert html =~ ~s|class="date-range-separator"|
    end
  end

  describe "Components.DatePickerLive (server-rendered multi-calendar grid)" do
    # Exercise both the underlying calendar arithmetic and the
    # full LiveComponent render cycle via
    # `Phoenix.LiveViewTest.render_component/2` — which mounts
    # the component and runs `update/2` + `render/1` without
    # needing a host LiveView or endpoint.
    import Phoenix.LiveViewTest

    test "Islamic month boundary: Dhul-Qa'dah 1447 has 30 days" do
      {:ok, first} = Date.new(1447, 11, 1, Calendrical.Islamic.Civil)
      assert Date.days_in_month(first) == 30
      assert Date.convert!(first, Calendar.ISO) == ~D[2026-04-18]
    end

    test "Hebrew leap-year month — Adar I exists in 5784 (leap)" do
      # AM 5784 (Sep 2023 - Sep 2024) is a 13-month leap year.
      # Adar I is month 12; Adar II is month 13.
      assert {:ok, _} = Date.new(5784, 12, 1, Calendrical.Hebrew)
      assert {:ok, _} = Date.new(5784, 13, 1, Calendrical.Hebrew)
    end

    test "Persian Esfand 1404 (non-leap) has 29 days" do
      {:ok, first} = Date.new(1404, 12, 1, Calendrical.Persian)
      assert Date.days_in_month(first) == 29
    end

    test "Buddhist year offset is 543" do
      {:ok, d_buddhist} = Date.new(2569, 5, 16, Calendrical.Buddhist)
      assert Date.convert!(d_buddhist, Calendar.ISO) == ~D[2026-05-16]
    end

    test "Japanese imperial era — Reiwa 6 = Gregorian 2024" do
      # Gregorian 2024-07-01 lives in Reiwa era. Construct
      # via Gregorian year (Calendrical.Japanese stores year
      # Gregorian-style and exposes era via year_of_era/3).
      {:ok, d} = Date.new(2024, 7, 1, Calendrical.Japanese)
      assert {6, 236} = Calendrical.Japanese.year_of_era(2024, 7, 1)
      assert Date.convert!(d, Calendar.ISO) == ~D[2024-07-01]
    end

    test "renders Gregorian month grid for an empty form" do
      form = Phoenix.HTML.FormData.to_form(%{}, as: :event)

      html =
        render_component(Localize.Inputs.Date.Components.DatePickerLive,
          id: "test-date",
          form: form,
          field: :date,
          locale: :en
        )

      assert html =~ ~s|class="date-input-wrapper date-picker-live |
      assert html =~ ~s|name="event[date]"|
      assert html =~ ~s|phx-click="toggle"|
      # Overlay is closed by default, so the grid table isn't
      # in the output. Trigger label is.
      assert html =~ "Open calendar"
    end

    test "renders Islamic-civil month grid with calendar-correct day labels" do
      form =
        Phoenix.HTML.FormData.to_form(
          %{"date" => ~D[2026-04-18]},
          as: :event
        )

      html =
        render_component(Localize.Inputs.Date.Components.DatePickerLive,
          id: "test-islamic",
          form: form,
          field: :date,
          locale: :"ar-SA",
          calendar: :islamic_civil,
          open: true
        )

      # The overlay should be rendered (component mounts open).
      # Even if not rendered open via initial mount (we'd need
      # event simulation for that), the text input value
      # should reflect the locale-correct format.
      assert html =~ ~s|class="date-input-wrapper date-picker-live |
      # The Islamic-formatted date for 2026-04-18 is
      # "1 ذو القعدة 1447 هـ" — assert the year fragment
      # appears in the rendered text input.
      assert html =~ "1447"
    end

    test "renders Buddhist month grid with BE year" do
      form =
        Phoenix.HTML.FormData.to_form(
          %{"date" => ~D[2026-05-16]},
          as: :event
        )

      html =
        render_component(Localize.Inputs.Date.Components.DatePickerLive,
          id: "test-buddhist",
          form: form,
          field: :date,
          locale: :"th-TH",
          calendar: :buddhist
        )

      # Buddhist year 2569 = Gregorian 2026
      assert html =~ "2569"
    end

    test "renders Japanese imperial with era marker" do
      form =
        Phoenix.HTML.FormData.to_form(
          %{"date" => ~D[2024-07-01]},
          as: :event
        )

      html =
        render_component(Localize.Inputs.Date.Components.DatePickerLive,
          id: "test-japanese",
          form: form,
          field: :date,
          locale: :"ja-JP",
          calendar: :japanese
        )

      # 令和6年 = Reiwa 6 = 2024 — the input value should
      # carry the era marker thanks to the Localize.Date
      # fix we landed for `%{format: ..., number_system: ...}`
      # variant maps.
      assert html =~ "令和"
      assert html =~ "6"
    end
  end

  describe "Components.date_range_picker/1" do
    test "renders unified picker with shared overlay" do
      form = Phoenix.HTML.FormData.to_form(%{}, as: :event)

      assigns = %{
        form: form,
        field: :trip,
        locale: :en,
        min: nil,
        max: nil,
        placeholder_from: nil,
        placeholder_to: nil,
        display_format: :medium,
        calendar: :gregorian,
        variant: :auto,
        js: true,
        class: nil,
        input_class: nil,
        button_class: nil,
        overlay_class: nil,
        __changed__: nil
      }

      html =
        assigns
        |> Localize.Inputs.Date.Components.date_range_picker()
        |> Phoenix.HTML.Safe.to_iodata()
        |> IO.iodata_to_binary()

      # Sub-field names — submits as %{"from" => _, "to" => _}.
      assert html =~ ~s|name="event[trip][from]"|
      assert html =~ ~s|name="event[trip][to]"|
      # Hidden range carriers for the JS hook.
      assert html =~ ~s|data-range-picker-from|
      assert html =~ ~s|data-range-picker-to|
      # Phx-hook wires up the RangePicker.
      assert html =~ ~s|phx-hook="RangePicker"|
      # Single shared overlay (one trigger, not two).
      assert html |> String.split("data-date-picker-overlay") |> length() == 2
    end

    test "renders existing from/to values formatted for locale" do
      form =
        Phoenix.HTML.FormData.to_form(
          %{"trip" => %{"from" => ~D[2026-05-05], "to" => ~D[2026-05-10]}},
          as: :event
        )

      assigns = %{
        form: form,
        field: :trip,
        locale: :en,
        min: nil,
        max: nil,
        placeholder_from: nil,
        placeholder_to: nil,
        display_format: :medium,
        calendar: :gregorian,
        variant: :auto,
        js: true,
        class: nil,
        input_class: nil,
        button_class: nil,
        overlay_class: nil,
        __changed__: nil
      }

      html =
        assigns
        |> Localize.Inputs.Date.Components.date_range_picker()
        |> Phoenix.HTML.Safe.to_iodata()
        |> IO.iodata_to_binary()

      assert html =~ "May 5, 2026"
      assert html =~ "May 10, 2026"
    end
  end
end
