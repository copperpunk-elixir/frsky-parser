defmodule FrskyParser.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/copperpunk-elixir/frsky-parser"

  def project do
    [
      app: :frsky_parser,
      version: @version,
      elixir: "~> 1.11",
      description: description(),
      package: package(),
      source_url: @source_url,
      docs: docs(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    "Parse SBus packets from an Frsky SBus receiver"
  end

  defp package do
    %{
      licenses: ["GPL-3.0"],
      links: %{"Github" => @source_url}

    }
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.24", only: :dev, runtime: false},
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp docs do
    [
      extras: ["README.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
