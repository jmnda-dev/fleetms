defmodule Fleetms.Ledger do
  use Ash.Domain,
    otp_app: :fleetms

  resources do
    resource Fleetms.Ledger.Account
    resource Fleetms.Ledger.Balance
    resource Fleetms.Ledger.Transfer
  end
end
