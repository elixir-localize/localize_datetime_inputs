defmodule Localize.Inputs.Date.AdversarialRenderTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Exercises every public component with adversarial attr
  values. Asserts no `RuntimeError`, `MatchError`,
  `ArgumentError`, `FunctionClauseError`, `KeyError`, or any
  other exception. Failing this test means a consumer could
  500 the render path with junk input — a rule-2 violation
  per the project's CLAUDE.md rules.

  The fixture matrix is deliberately small and per-attr
  (not full Cartesian) to keep the suite fast; the goal is
  to catch new code paths that fail to handle each
  problematic value class, not to exhaustively test every
  combination.
  """

  alias Localize.Inputs.Date.Components

  # Adversarial value classes per attr type. Each list is
  # tried in turn against the targeted attr; the rest of
  # the assigns keep their happy-path values.
  @bad_atoms [nil, :"", :unknown, :__bad__]
  @bad_strings [nil, "", "garbage", "🙂", String.duplicate("a", 1000)]
  @bad_dates [nil, "", "not-a-date", "9999-99-99", %{}, [], 42]
  @bad_bounds [nil, "", "not-a-date", "9999-99-99", :"", %{}, 42]

  describe "date_input/1" do
    setup do
      _ = :__bad__
      :ok
    end

    test "renders for every adversarial :locale" do
      for locale <- @bad_atoms ++ @bad_strings do
        assert_no_raise(fn -> render(:date_input, locale: locale) end,
          context: "locale=#{inspect(locale)}"
        )
      end
    end

    test "renders for every adversarial :calendar" do
      for cal <- @bad_atoms do
        assert_no_raise(fn -> render(:date_input, calendar: cal) end,
          context: "calendar=#{inspect(cal)}"
        )
      end
    end

    test "renders for every adversarial :value" do
      for value <- @bad_dates do
        assert_no_raise(fn -> render(:date_input, value: value) end,
          context: "value=#{inspect(value)}"
        )
      end
    end

    test "renders for every adversarial :min / :max" do
      for bound <- @bad_bounds do
        assert_no_raise(fn -> render(:date_input, min: bound) end,
          context: "min=#{inspect(bound)}"
        )

        assert_no_raise(fn -> render(:date_input, max: bound) end,
          context: "max=#{inspect(bound)}"
        )
      end
    end

    test "renders for every adversarial :display_format" do
      for fmt <- @bad_atoms do
        assert_no_raise(fn -> render(:date_input, display_format: fmt) end,
          context: "display_format=#{inspect(fmt)}"
        )
      end
    end
  end

  describe "date_range_input/1" do
    test "renders for adversarial :field — must NOT require pre-declared atoms" do
      # The historical regression: 0.1.1 used `String.to_existing_atom`
      # for the derived `{field}_from` / `{field}_to` child atoms,
      # which 500s when the consumer's schema hasn't loaded them.
      # `:__never_declared__` is an atom whose `_from`/`_to`
      # children deliberately don't exist anywhere; this test
      # MUST pass.
      assert_no_raise(fn -> render(:date_range_input, field: :__never_declared__) end,
        context: "field=:__never_declared__"
      )
    end

    test "renders for every adversarial :locale" do
      for locale <- @bad_atoms ++ @bad_strings do
        assert_no_raise(fn -> render(:date_range_input, locale: locale) end,
          context: "locale=#{inspect(locale)}"
        )
      end
    end

    test "renders for every adversarial :calendar" do
      for cal <- @bad_atoms do
        assert_no_raise(fn -> render(:date_range_input, calendar: cal) end,
          context: "calendar=#{inspect(cal)}"
        )
      end
    end
  end

  describe "date_range_picker/1" do
    test "renders for every adversarial :locale" do
      for locale <- @bad_atoms ++ @bad_strings do
        assert_no_raise(fn -> render(:date_range_picker, locale: locale) end,
          context: "locale=#{inspect(locale)}"
        )
      end
    end

    test "renders for every adversarial :calendar" do
      for cal <- @bad_atoms do
        assert_no_raise(fn -> render(:date_range_picker, calendar: cal) end,
          context: "calendar=#{inspect(cal)}"
        )
      end
    end

    test "renders for adversarial nested from/to values" do
      for value <- @bad_dates do
        # The picker stores `:trip` as a map `%{"from" =>, "to" =>}`.
        form =
          Phoenix.HTML.FormData.to_form(%{"trip" => %{"from" => value, "to" => value}},
            as: :event
          )

        assert_no_raise(fn -> render(:date_range_picker, form: form, value: value) end,
          context: "trip=%{from: #{inspect(value)}, to: #{inspect(value)}}"
        )
      end
    end
  end

  # ── Helpers ───────────────────────────────────────────────

  defp render(component, overrides) do
    base_form =
      Phoenix.HTML.FormData.to_form(%{"date" => "", "trip" => %{"from" => "", "to" => ""}},
        as: :event
      )

    base_assigns = %{
      __changed__: nil,
      form: base_form,
      field: :date,
      value: nil,
      locale: :en,
      min: nil,
      max: nil,
      placeholder: nil,
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
      rest: %{}
    }

    assigns = Map.merge(base_assigns, Map.new(overrides))

    rendered =
      case component do
        :date_input -> Components.date_input(assigns)
        :date_range_input -> Components.date_range_input(Map.put(assigns, :field, :trip))
        :date_range_picker -> Components.date_range_picker(Map.put(assigns, :field, :trip))
      end

    # Also force the rendered iodata to actually serialise —
    # some defects only surface at `Phoenix.HTML.Safe.to_iodata`.
    _ = rendered |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()
    :ok
  end

  defp assert_no_raise(fun, context: ctx) do
    try do
      fun.()
    rescue
      e ->
        flunk("""
        Component raised an exception under #{ctx}:

          #{Exception.format(:error, e, [])}
        """)
    end
  end
end
