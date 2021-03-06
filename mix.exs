defmodule AbsintheAuth.Mixfile do
  use Mix.Project

  @version "0.1.0"

  def project do
    [app: :blanka,
     version: @version,
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     package: package(),
     docs: [
      main: "Blanka",
      extras: ["README.md"]
    ]]
  end


  defp package do
    [description: "Blanka - Abinsthe Authorization",
     files: ["lib", "mix.exs", "README*"],
     maintainers: ["Marcus Orochena"],
     licenses: ["BSD"],
     links: %{github: "https://github.com/morochena/blanka"}]
  end


  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  def deps do
    [{:ex_doc, "~> 0.16", only: :dev, runtime: false}]
  end
end
