defmodule Unfurl.Mixfile do
  use Mix.Project

  def project do
    [
      app: :unfurl,
      version: "0.6.2",
      elixir: "~> 1.10",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      name: "Unfurl",
      source_url: "https://github.com/bonfire-networks/unfurl",
      docs: [
        main: "Unfurl",
        extras: ~w(README.md CHANGELOG.md)
      ]
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [
      mod: {Unfurl, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:tesla, "~> 1.4"},
      # refuses private/reserved addresses on every request and redirect hop
      {:req_ssrf, "~> 0.2"},
      {:process_tree, "~> 0.3.0"},
      # optional, but recommended adapter for tesla
      {:hackney, "~> 1.25 or ~> 4.9", optional: true},
      {:floki, "~> 0.32"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.6", optional: true},
      {:arrows, "~> 0.2"},
      {:untangle, "~> 0.5"},
      {:benchee, "~> 1.0", only: :dev},
      {:ex_doc, "~> 0.28", only: :dev, runtime: false},
      {:bypass, "~> 2.1", only: :test},
      # tests use the sibling fork when it's checked out next to this one (e.g. in bonfire-app's forks/), so they run against unreleased fixes (but not when publishing, which can't have path deps)
      if(Mix.env() == :test and File.exists?(Path.expand("../faviconic/mix.exs", __DIR__)),
        do: {:faviconic, path: "../faviconic"},
        else: {:faviconic, "~> 0.3"}
      )
      # {:faviconic, git: "https://github.com/bonfire-networks/faviconic"}
    ]
  end

  defp description do
    """
    Unfurl is a structured data extraction tool written in Elixir.

    It currently supports unfurling oEmbed, Twitter Card, Facebook Open Graph, JSON-LD
    and plain ole' HTML `<meta />` data out of any url you supply.
    """
  end

  defp package do
    [
      name: :unfurl,
      files: ~w(lib mix.exs README.md LICENSE.md CHANGELOG.md),
      maintainers: ["Bonfire Networks"],
      licenses: ["Apache-2.0"],
      links: %{
        "Github" => "https://github.com/bonfire-networks/unfurl",
        "Docs" => "http://hexdocs.pm/unfurl"
      }
    ]
  end
end
