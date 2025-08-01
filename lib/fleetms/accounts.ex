defmodule Fleetms.Accounts do
  use Ash.Domain, otp_app: :fleetms, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Fleetms.Accounts.Token
    resource Fleetms.Accounts.User
    resource Fleetms.Accounts.ApiKey
  end
end
