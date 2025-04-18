defmodule Fleetms.MixProject do
  use Mix.Project

  def project do
    [
      app: :fleetms,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Fleetms.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0-rc.1", override: true},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.2"},
      {:esbuild, "~> 0.7", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2.0", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.3"},
      {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},
      {:ash, "~> 3.4.0"},
      {:picosat_elixir, "~> 0.2"},
      {:ash_postgres, "~> 2.4"},
      {:ash_phoenix, "~> 2.0"},
      {:ash_authentication, "~> 4.0"},
      {:ash_authentication_phoenix, "~> 2.0"},
      {:timex, "~> 3.7"},
      {:waffle, "~> 1.1"},
      {:ash_admin, "~> 0.11"},
      {:ash_money, "~> 0.1"},
      {:ex_money_sql, "~> 1.0"},
      {:ex_cldr_units, "~> 3.16"},
      {:benchee, "~> 1.0", only: :dev},
      {:nimble_csv, "~> 1.2"},
      {:sentry, "~> 10.2.0"},
      {:hackney, "~> 1.8"},
      {:ecto_psql_extras, "~> 0.6"},
      {:fun_with_flags, "~> 1.12.0"},
      {:fun_with_flags_ui, "~> 0.8"},
      {:dotenvy, "~> 0.8.0"},
      {:multipart, "~> 0.4.0"},
      {:oban, "~> 2.17"},
      {:req, "~> 0.5.6"},
      {:faker, "~> 0.18"},
      {:live_toast, "~> 0.6.4"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: [
        "deps.get",
        "compile",
        "assets.setup",
        "assets.build",
        "ash.reset",
        "run priv/repo/seeds.exs"
      ],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      seed: [
        "ash.reset",
        "run priv/repo/seeds.exs"
      ],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": [
        "tailwind default --minify",
        "esbuild default --minify",
        "phx.digest"
      ]
    ]
  end
end
