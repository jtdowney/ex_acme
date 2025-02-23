defmodule ExAcme.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_acme,
      name: "ExAcme",
      version: "0.1.0",
      elixir: "~> 1.15",
      licenses: ["MIT"],
      source_url: "https://github.com/jtdowney/ex_acme",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      docs: docs(),
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs do
    [
      main: "ExAcme",
      extras: ["README.md"]
    ]
  end

  defp deps do
    [
      {:assert_eventually, "~> 1.0", only: [:dev, :test]},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:faker, "~> 0.18.0", only: [:dev, :test]},
      {:finch, "~> 0.19.0"},
      {:jason, "~> 1.4"},
      {:jose, "~> 1.11"},
      {:mix_test_watch, "~> 1.2", only: [:dev, :test], runtime: false},
      {:styler, "~> 1.3", only: [:dev, :test], runtime: false},
      {:x509, "~> 0.8.10"}
    ]
  end

  defp aliases do
    []
  end
end
