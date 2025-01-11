# # To learn more about how to use Nix to configure your environment
# # see: https://developers.google.com/idx/guides/customize-idx-env
# { pkgs, ... }: {
#   # Which nixpkgs channel to use.
#   channel = "stable-24.05"; # or "unstable"

#   # Use https://search.nixos.org/packages to find packages
#   packages = [
#     # pkgs.go
#     # pkgs.python311
#     # pkgs.python311Packages.pip
#     # pkgs.nodejs_20
#     # pkgs.nodePackages.nodemon
#   ];

#   # Sets environment variables in the workspace
#   env = {};
#   idx = {
#     # Search for the extensions you want on https://open-vsx.org/ and use "publisher.id"
#     extensions = [
#       # "vscodevim.vim"
#     ];

#     # Enable previews
#     previews = {
#       enable = true;
#       previews = {
#         # web = {
#         #   # Example: run "npm run dev" with PORT set to IDX's defined port for previews,
#         #   # and show it in IDX's web preview panel
#         #   command = ["npm" "run" "dev"];
#         #   manager = "web";
#         #   env = {
#         #     # Environment variables to set for your server
#         #     PORT = "$PORT";
#         #   };
#         # };
#       };
#     };

#     # Workspace lifecycle hooks
#     workspace = {
#       # Runs when a workspace is first created
#       onCreate = {
#         # Example: install JS dependencies from NPM
#         # npm-install = "npm install";
#       };
#       # Runs when the workspace is (re)started
#       onStart = {
#         # Example: start a background task to watch and re-build backend code
#         # watch-backend = "npm run watch-backend";
#       };
#     };
#   };
# }

{ pkgs, ... }: {
  channel = "stable-24.05";

  packages = [
    pkgs.gnumake
    pkgs.htop
    pkgs.gcc
    pkgs.erlang
    pkgs.elixir
    pkgs.nodejs_20
    pkgs.postgresql_16
    pkgs.git
    pkgs.elixir-ls
    pkgs.hex
    pkgs.rebar3
    pkgs.inotify-tools
  ];

  services.postgres = {
    enable = true;
    enableTcp = true;
  };

  env = {
    # Use TCP connection instead of Unix socket
    DATABASE_URL = "postgresql://postgres:postgres@localhost:5432/fleetms_dev";
    MIX_ENV = "dev";
  };

  idx = {
    extensions = [
      "elixir-lsp.elixir-ls"
      "elixir-tools.elixir-tools"
      "florinpatrascu.vscode-elixir-snippets"
      "aziz-abdullaev.heex-snippets"
      "benvp.vscode-hex-pm-intellisense"
      "bradlc.vscode-tailwindcss"
      "vscodevim.vim"
    ];

    workspace = {
      onCreate = {
        setup-project = pkgs.writeShellScript "setup-project" ''
          # Ensure PostgreSQL is running
          if ! pg_isready -h localhost -p 5432 > /dev/null 2>&1; then
            echo "Waiting for PostgreSQL to start..."
            for i in {1..30}; do
              if pg_isready -h localhost -p 5432 > /dev/null 2>&1; then
                break
              fi
              sleep 1
            done
          fi

          # Create the 'postgres' user if it doesn't exist
          psql -U postgres -d postgres -h localhost -c '\du' 2>/dev/null | grep postgres > /dev/null || (
            echo "Creating 'postgres' role..."
            psql -U postgres -d postgres -h localhost -c "CREATE ROLE postgres WITH SUPERUSER CREATEDB CREATEROLE LOGIN PASSWORD 'postgres';"
          )

          # Create necessary databases
          echo "Ensuring required databases exist..."
          createdb -U postgres -h localhost fleetms_dev || true
          
          createdb -U postgres -h localhost fleetms_test || true
          mix setup
        '';
      };
    };

    previews = {
      enable = true;
      previews = {
        web = {
          command = [ "mix" "phx.server" ];
          manager = "web";
          env = {
            PORT = "$PORT";
            MIX_ENV = "dev";
            # Pass the same database URL to the preview
            DATABASE_URL = "postgresql://postgres:postgres@localhost:5432/fleetms_dev";
          };
        };
      };
    };
  };
}
