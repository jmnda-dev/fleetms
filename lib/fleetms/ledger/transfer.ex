defmodule Fleetms.Ledger.Transfer do
  use Ash.Resource,
    domain: Elixir.Fleetms.Ledger,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshDoubleEntry.Transfer]

  transfer do
    account_resource Fleetms.Ledger.Account
    balance_resource Fleetms.Ledger.Balance
  end

  postgres do
    table "ledger_transfers"
    repo Fleetms.Repo
  end

  actions do
    defaults [:read]

    create :transfer do
      accept [:amount, :timestamp, :from_account_id, :to_account_id]
    end
  end

  attributes do
    attribute :id, AshDoubleEntry.ULID do
      primary_key? true
      allow_nil? false
      default &AshDoubleEntry.ULID.generate/0
    end

    attribute :amount, :money do
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :from_account, Fleetms.Ledger.Account do
      attribute_writable? true
    end

    belongs_to :to_account, Fleetms.Ledger.Account do
      attribute_writable? true
    end

    has_many :balances, Fleetms.Ledger.Balance
  end
end
