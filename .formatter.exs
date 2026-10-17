[
  import_deps: [
    :ash_admin,
    :ash_authentication_phoenix,
    :ash_authentication,
    :ash_postgres,
    :ash_phoenix,
    :ash_state_machine,
    :ash_oban,
    :ash,
    :reactor,
    :ecto,
    :ecto_sql,
    :phoenix
  ],
  # `permission` is our local Permissions DSL (Fleetms.Permissions.Dsl); list it so
  # the formatter leaves it paren-less like the built-in Ash DSL entities.
  locals_without_parens: [permission: 2],
  subdirectories: ["priv/*/migrations"],
  plugins: [Spark.Formatter, Phoenix.LiveView.HTMLFormatter],
  inputs: ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}", "priv/*/seeds.exs"]
]
