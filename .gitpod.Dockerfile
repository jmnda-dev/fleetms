FROM gitpod/workspace-full

ENV PGWORKSPACE="/workspace/.pgsql"
ENV PGDATA="$PGWORKSPACE/data"

RUN sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' \
    && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - \
    && sudo apt -y update

# Install PostgreSQL 15
# If you are fine with an older version, you can skip the PostgreSQL block
# and just use FROM gitpod/workspace-postgres as base image.
RUN sudo install-packages postgresql-15 postgresql-contrib-15

# Setup PostgreSQL server for user gitpod
ENV PATH="/usr/lib/postgresql/15/bin:$PATH"

SHELL ["/usr/bin/bash", "-c"]
RUN PGDATA="${PGDATA//\/workspace/$HOME}" \
 && mkdir -p ~/.pg_ctl/bin ~/.pg_ctl/sockets $PGDATA \
 && initdb -D $PGDATA \
 && printf '#!/bin/bash\npg_ctl -D $PGDATA -l ~/.pg_ctl/log -o "-k ~/.pg_ctl/sockets" start\n' > ~/.pg_ctl/bin/pg_start \
 && printf '#!/bin/bash\npg_ctl -D $PGDATA -l ~/.pg_ctl/log -o "-k ~/.pg_ctl/sockets" stop\n' > ~/.pg_ctl/bin/pg_stop \
 && chmod +x ~/.pg_ctl/bin/* \
 && printf '%s\n' '# Auto-start PostgreSQL server' \
                  "test ! -e \$PGWORKSPACE && test -e ${PGDATA%/data} && mv ${PGDATA%/data} /workspace" \
                  '[[ $(pg_ctl status | grep PID) ]] || pg_start > /dev/null' > ~/.bashrc.d/200-postgresql-launch
ENV PATH="$HOME/.pg_ctl/bin:$PATH"
ENV DATABASE_URL="postgresql://gitpod@localhost"
ENV PGHOSTADDR="127.0.0.1"
ENV PGDATABASE="postgres"

# Erlang dependencies
RUN sudo install-packages curl gnupg build-essential autoconf m4 libncurses5-dev libwxgtk3.0-gtk3-dev libwxgtk-webview3.0-gtk3-dev \
    libgl1-mesa-dev libglu1-mesa-dev libpng-dev libssh-dev unixodbc-dev xsltproc fop libxml2-utils libncurses-dev openjdk-11-jdk

# Phoenix Dependencies
RUN sudo install-packages inotify-tools

RUN brew install asdf \
    && asdf plugin add erlang \
    && asdf plugin add elixir \
    && asdf plugin add neovim \
    # && asdf plugin add nodejs \
    && asdf install erlang 26.2.4 \
    && asdf global erlang 26.2.4 \
    && asdf install elixir 1.16.2-otp-26 \
    && asdf global elixir 1.16.2-otp-26 \
    && asdf install neovim stable \
    && asdf global neovim stable \
    # && asdf install nodejs 20 \
    # && asdf global nodejs 20 \
    && bash -c ". $(brew --prefix asdf)/libexec/asdf.sh \
        && mix local.hex --force \
        && mix local.rebar --force" \
    && echo -e "\n. $(brew --prefix asdf)/libexec/asdf.sh" >> ~/.bashrc

# Build vscode-elixir-ls extension
#
# We build this manually because ElixirLS won't show autocompletions
# when using the `use` macro if ElixirLS has been compiled with a different
# Erlang / Elixir combination. See https://github.com/elixir-lsp/elixir-ls/issues/193
#
# Aditionally, OpenVSX only contains a version published under the deprecated namespace.
# This causes issues when developing locally because it would always install the wrong extension.

RUN bash -c ". $(brew --prefix asdf)/libexec/asdf.sh \
    && git clone --recursive --branch v0.20.0 https://github.com/elixir-lsp/vscode-elixir-ls.git /tmp/vscode-elixir-ls \
    && cd /tmp/vscode-elixir-ls \
    && npm install \
    && cd elixir-ls \
    && mix deps.get \
    && cd .. \
    && npx vsce package \
    && mkdir -p $HOME/extensions \
    && cp /tmp/vscode-elixir-ls/elixir-ls-0.20.0.vsix $HOME/extensions \
    && cd $HOME \
    && rm -rf /tmp/vscode-elixir-ls"
