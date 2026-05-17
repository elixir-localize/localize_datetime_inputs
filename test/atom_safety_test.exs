defmodule Localize.Inputs.Date.AtomSafetyTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Compile-time guard against `String.to_atom/1` and equivalents
  on potentially-untrusted input. Atoms aren't garbage-collected;
  any code path that converts arbitrary strings to atoms is a
  DoS vector — an attacker spraying unique values exhausts the
  atom table and crashes the BEAM.
  """

  @lib_root Path.expand("../lib", __DIR__)

  # Patterns held as binaries — not compiled `~r/.../`
  # structs — because compiled regexes hold internal
  # references that Elixir < 1.20 refuses to inject into a
  # function via `@`-attribute escaping. Compile at test
  # time instead.
  @forbidden [
    {~S/String\.to_atom\(/, "String.to_atom/1"},
    {~S/:erlang\.binary_to_atom\(/, ":erlang.binary_to_atom/1,2"},
    {~S/Module\.concat\(\s*\[/, "Module.concat/1 on a list of untrusted strings"}
  ]

  @allowlist ["localize/inputs/date/components.ex"]

  test "no String.to_atom (or equivalent) on untrusted input in lib/" do
    files = Path.wildcard("#{@lib_root}/**/*.ex")

    compiled = for {src, label} <- @forbidden, do: {Regex.compile!(src, "u"), label}

    violations =
      for file <- files,
          {pattern, label} <- compiled,
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
      with a graceful fallback.

      Violations:

      #{lines}
      """)
    end
  end
end
