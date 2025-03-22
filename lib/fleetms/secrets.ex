defmodule Fleetms.Secrets do
  use AshAuthentication.Secret

  def secret_for([:authentication, :tokens, :signing_secret], Fleetms.Accounts.User, _opts) do
    Application.fetch_env(:fleetms, :token_signing_secret)
  end
end
