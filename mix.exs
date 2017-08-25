defmodule AbsintheAuth.Mixfile do
  use Mix.Project

  @version "0.1.0"

  def project do
    [app: :absinthe_auth,
     version: @version,
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end


  defp package do
    [description: "Abinsthe Authorization",
     files: ["lib", "priv", "mix.exs", "README*"],
     maintainers: ["Marcus Orochena"],
     licenses: ["BSD"],
     links: %{github: "https://github.com/morochena/absinthe_authorization"}]
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
  defp deps do
    []
  end
end
