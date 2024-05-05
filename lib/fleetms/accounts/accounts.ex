defmodule Fleetms.Accounts do
  @moduledoc """
  A Ash domain module for interacting with resources in the Accounts context.
  """
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  resources do
    resource Fleetms.Accounts.Organization

    resource Fleetms.Accounts.User do
      define :get_user_by_id, action: :get_by_id, args: [:id]
    end

    resource Fleetms.Accounts.UserProfile
    resource Fleetms.Accounts.Token
  end

  admin do
    show? true
  end
end
