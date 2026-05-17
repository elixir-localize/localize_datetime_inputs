defmodule Localize.DateTimeInputs.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/elixir-localize/localize_datetime_inputs"

  def project do
    [
      app: :localize_datetime_inputs,
      version: @version,
      name: "Localize.Inputs.Date",
      source_url: @source_url,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [
        plt_add_apps: ~w(gettext mix phoenix_html phoenix_live_view)a,
        flags: [
          :error_handling,
          :unknown,
          :underspecs,
          :extra_return,
          :missing_return
        ]
      ]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp description do
    "Locale-aware date/time form input components for Phoenix LiveView. " <>
      "`<.date_input>`, `<.date_range_input>`, `<.date_range_picker>`, and " <>
      "`DatePickerLive` — built on `calendrical` for multi-calendar (Gregorian, " <>
      "Buddhist, Japanese imperial, Islamic, Persian, Hebrew, ROC, …) support."
  end

  defp package do
    [
      maintainers: ["Kip Cole"],
      licenses: ["Apache-2.0"],
      links: links(),
      files: ~w(lib priv mix.exs README.md CHANGELOG.md LICENSE.md)
    ]
  end

  defp links do
    %{
      "GitHub" => @source_url,
      "Readme" => "#{@source_url}/blob/v#{@version}/README.md",
      "Changelog" => "#{@source_url}/blob/v#{@version}/CHANGELOG.md"
    }
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      main: "readme",
      extras: ["README.md", "CHANGELOG.md", "LICENSE.md"],
      formatters: ["html", "markdown"]
    ]
  end

  defp deps do
    [
      {:localize, "~> 0.37"},
      {:calendrical, "~> 0.5"},
      {:localize_inputs_core, "~> 0.1"},
      {:phoenix_html, "~> 4.0", optional: true},
      {:phoenix_live_view, "~> 1.0", optional: true},
      {:gettext, "~> 1.0", optional: true},
      {:ex_doc, "~> 0.30", only: [:dev, :release], runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false}
    ] ++ maybe_json_polyfill()
  end

  defp maybe_json_polyfill do
    if Code.ensure_loaded?(:json) do
      []
    else
      [{:json_polyfill, "~> 0.2 or ~> 1.0"}]
    end
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
