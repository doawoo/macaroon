defmodule Macaroon.MixProject do
  use Mix.Project

  def project do
    [
      app: :macaroon,
      version: "0.2.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      package: package(),
      docs: [main: "readme", extras: ["README.md"]]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:excoveralls, "~> 0.13", only: [:test]},
      {:ex_doc, "~> 0.24", only: :dev, runtime: false},
      {:typed_struct, "~> 0.2"},
      {:jason, "~> 1.2"},
      {:enacl, "~> 1.1"}
    ]
  end

  defp package do
    [
      links: %{
        "GitHub" => "https://github.com/doawoo/macaroon",
        "Paper (Birgisson, Arnar, et al.)" => "https://research.google/pubs/pub41892/"
      },
      description: "Library that implements Macaroons in Elixir",
      licenses: ["MIT"]
    ]
  end
end
