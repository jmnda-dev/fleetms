ARG ELIXIR_VERSION=1.17.2
ARG OTP_VERSION=27.0
ARG UBUNTU_VERSION=jammy-20240530

ARG IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-ubuntu-${UBUNTU_VERSION}"
FROM ${IMAGE}

# This Dockerfile adds a non-root user with sudo access. Update the “remoteUser” property in
# devcontainer.json to use it. More info: https://aka.ms/vscode-remote/containers/non-root-user.
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Options for common package install script
ARG INSTALL_ZSH="true"
ARG UPGRADE_PACKAGES="true"
ARG COMMON_SCRIPT_SOURCE="https://raw.githubusercontent.com/microsoft/vscode-dev-containers/v0.209.6/script-library/common-debian.sh"
ARG COMMON_SCRIPT_SHA="d35dd1711454156c9a59cc41ebe04fbff681ca0bd304f10fd5b13285d0de13b2"

# Settings for Phoenix
ARG PHOENIX_VERSION="1.7.14"

# Setup nodejs
ARG NODE_SCRIPT_SOURCE="https://raw.githubusercontent.com/microsoft/vscode-dev-containers/main/script-library/node-debian.sh"
ARG NODE_SCRIPT_SHA="dev-mode"
ARG NODE_VERSION="lts/*"
ENV NVM_DIR=/usr/local/share/nvm
ENV NVM_SYMLINK_CURRENT=true
ENV PATH=${NVM_DIR}/current/bin:${PATH}

# Install needed packages and setup non-root user. Use a separate RUN statement to add your own dependencies.
RUN apt-get update \
  && export DEBIAN_FRONTEND=noninteractive \
  && apt-get -y install --no-install-recommends curl ca-certificates 2>&1 \
  && curl -sSL ${COMMON_SCRIPT_SOURCE} -o /tmp/common-setup.sh \
  && ([ "${COMMON_SCRIPT_SHA}" = "dev-mode" ] || (echo "${COMMON_SCRIPT_SHA} */tmp/common-setup.sh" | sha256sum -c -)) \
  && /bin/bash /tmp/common-setup.sh "${INSTALL_ZSH}" "${USERNAME}" "${USER_UID}" "${USER_GID}" "${UPGRADE_PACKAGES}" \
  && apt-get install -y build-essential \
  && apt-get install -y postgresql-client inotify-tools gnupg2 dirmngr gpg gawk \
  #
  # [Optional] Install Node.js for use with web applications
  # && if [ "$NODE_VERSION" != "none" ]; then \
  # curl -sSL ${NODE_SCRIPT_SOURCE} -o /tmp/node-setup.sh \
  # && ([ "${NODE_SCRIPT_SHA}" = "dev-mode" ] || (echo "${NODE_SCRIPT_SHA} */tmp/node-setup.sh" | sha256sum -c -)) \
  # && /bin/bash /tmp/node-setup.sh "${NVM_DIR}" "${NODE_VERSION}" "${USERNAME}"; \
  # fi \
  #
  # Install dependencies
  #
  # Clean up
  && apt-get autoremove -y \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/* /tmp/common-setup.sh /tmp/node-setup.sh

RUN su ${USERNAME} -c "mix local.hex --force \
  && mix local.rebar --force \
  && mix archive.install --force hex phx_new ${PHOENIX_VERSION}"

# [Optional] Uncomment this section to install additional OS packages.
# RUN apt-get update \
#     && export DEBIAN_FRONTEND=noninteractive \
#     && apt-get -y install --no-install-recommends <your-package-list-here>

# [Optional] Uncomment this line to install additional package.
# RUN  mix ...
RUN curl -sL https://deb.nodesource.com/setup_20.x | bash - \
  && apt-get install nodejs -y \
  && apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
  && apt-get -y install imagemagick \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

