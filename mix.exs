defmodule ExAcme.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_acme,
      name: "ExAcme",
      version: "0.5.2",
      elixir: "~> 1.15",
      source_url: "https://github.com/jtdowney/ex_acme",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      description: description(),
      docs: docs(),
      deps: deps(),
      preferred_cli_env: preferred_cli_env(),
      dialyzer: dialyzer()
    ]
  end

  def application do
    [
      extra_applications: [:inets]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      maintainers: ["John Downey"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/jtdowney/ex_acme",
        "Changelog" => "https://github.com/jtdowney/ex_acme/blob/main/CHANGELOG.md"
      }
    ]
  end

  defp description do
    "A library for interacting with ACME servers like Let's Encrypt."
  end

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
      {:excoveralls, "~> 0.18.5", only: [:dev, :test]},
      {:faker, "~> 0.18.0", only: [:dev, :test]},
      {:jason, "~> 1.4"},
      {:jose, "~> 1.11"},
      {:mix_test_watch, "~> 1.2", only: [:dev, :test], runtime: false},
      {:req, "~> 0.5.8"},
      {:styler, "~> 1.3", only: [:dev, :test], runtime: false},
      {:x509, "~> 0.8.10"}
    ]
  end

  defp preferred_cli_env do
    [
      coveralls: :test,
      "coveralls.detail": :test,
      "coveralls.post": :test,
      "coveralls.html": :test,
      "coveralls.cobertura": :test
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:ex_unit]
    ]
  end
end
