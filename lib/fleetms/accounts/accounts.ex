defmodule Fleetms.Accounts do
  @moduledoc """
  A Ash domain module for interacting with resources in the Accounts context.
  """
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  resources do
    resource Fleetms.Accounts.Organization
    resource Fleetms.Accounts.User
    resource Fleetms.Accounts.UserProfile
    resource Fleetms.Accounts.Token
  end

  admin do
    show? true
  end
end
