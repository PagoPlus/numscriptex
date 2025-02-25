defmodule Numscriptex.MixProject do
  use Mix.Project

  @source_url "https://github.com/PagoPlus/numscriptex"
  @version "0.2.2"

  def project do
    [
      app: :numscriptex,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      description: "Numscript support for Elixir",
      aliases: aliases(),
      deps: deps(),
      package: package(),
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        "coveralls.html": :test,
        coveralls: :test,
        ci: :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:wasmex, "~> 0.9.2"},
      {:excoveralls, "~> 0.18", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      ci: [
        "deps.unlock --check-unused",
        "credo suggest --strict --all",
        "test"
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      name: "NumscriptEx",
      extra_section: "guides",
      suorce_ref: "v#{@version}",
      source_url: @source_url,
      extras: extras(),
      groups_for_extras: groups_for_extras()
    ]
  end

  defp extras do
    [
      "README.md": [
        title: "Readme"
      ],
      "guides/builder.md": [
        title: "Building Numscripts",
        filename: "builder-introduction"
      ]
    ]
  end

  defp groups_for_extras() do
    [
      Tutorial: Path.wildcard("guides/*.md")
    ]
  end

  defp package do
    %{
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      maintaners: ["Vinicius Costa", "Fernando Mumbach"]
    }
  end
end
