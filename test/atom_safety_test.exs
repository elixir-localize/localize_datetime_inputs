defmodule Localize.Inputs.Date.AtomSafetyTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Compile-time guard against `String.to_atom/1` and equivalents
  on potentially-untrusted input. Atoms aren't garbage-collected;
  any code path that converts arbitrary strings to atoms is a
  DoS vector — an attacker spraying unique values exhausts the
  atom table and crashes the BEAM.

  This test scans `lib/` for the dangerous forms and fails the
  suite if any new ones appear. Add to the allowlist below ONLY
  with a written justification of why the input is bounded
  (e.g. compile-time component attrs) AND a per-call comment
  in the source explaining the same.
  """

  @lib_root Path.expand("../lib", __DIR__)

  # Patterns we never want to see in lib code.
  @forbidden [
    {~r/String\.to_atom\(/, "String.to_atom/1"},
    {~r/:erlang\.binary_to_atom\(/, ":erlang.binary_to_atom/1,2"},
    {~r/Module\.concat\(\s*\[/, "Module.concat/1 on a list of untrusted strings"}
  ]

  # Files (relative to lib/) where a forbidden call is allowed.
  # Each entry MUST be accompanied by a justification.
  @allowlist [
    # `range_child_field/2` falls back to `String.to_atom` when
    # the `:<field>_from` / `:<field>_to` atom hasn't been
    # loaded yet. The `@field` attr is a developer-supplied
    # component attribute (bounded by source code), not URL
    # input. See `Localize.Inputs.Date.Components.range_child_field/2`
    # for the explanation.
    "localize/inputs/date/components.ex"
  ]

  test "no String.to_atom (or equivalent) on untrusted input in lib/" do
    files = Path.wildcard("#{@lib_root}/**/*.ex")

    violations =
      for file <- files,
          {pattern, label} <- @forbidden,
          rel = Path.relative_to(file, @lib_root),
          rel not in @allowlist,
          {line, line_idx} <- file |> File.read!() |> String.split("\n") |> Enum.with_index(),
          not String.starts_with?(String.trim_leading(line), "#"),
          Regex.match?(pattern, line),
          do: {rel, line_idx + 1, label, String.trim(line)}

    if violations != [] do
      lines =
        violations
        |> Enum.map(fn {file, lnum, label, src} ->
          "  #{file}:#{lnum}  (#{label})\n    #{src}"
        end)
        |> Enum.join("\n\n")

      flunk("""
      Forbidden atom-creation call found in lib/. Use
      `String.to_existing_atom/1` and rescue `ArgumentError`
      with a graceful fallback. If the call site is provably
      safe (input is bounded by source code), add the file
      to `@allowlist` in this test with a written
      justification.

      Violations:

      #{lines}
      """)
    end
  end
end
