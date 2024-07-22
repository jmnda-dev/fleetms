defmodule Fleetms.Accounts.Token do
  @moduledoc false
  use Ash.Resource,
    domain: Fleetms.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource],
    authorizers: [
      Ash.Policy.Authorizer
    ]

  policies do
    policy always() do
      authorize_if always()
    end
  end

  token do
    domain Fleetms.Accounts
  end

  postgres do
    table "tokens"
    repo Fleetms.Repo
  end

  multitenancy do
    strategy :context
    global? true
  end
end
