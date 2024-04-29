defmodule Fleetms.Accounts.Token do
  @moduledoc """
  A Token resource
  """
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource],
    domain: Fleetms.Accounts

  postgres do
    table "tokens"
    repo Fleetms.Repo
  end
end
