defmodule Fleetms.Accounts.UserProfile do
  @moduledoc """
  A User Profile resource
  """
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Fleetms.Accounts

  attributes do
    uuid_primary_key :id

    attribute :first_name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :last_name, :string do
      allow_nil? true
      public? true
      constraints max_length: 100
    end

    attribute :other_name, :string do
      allow_nil? true
      public? true
      constraints max_length: 100
    end

    attribute :address, :string do
      allow_nil? true
      public? true
      constraints max_length: 500
    end

    attribute :city, :string do
      allow_nil? true
      public? true
      constraints max_length: 50
    end

    attribute :state, :string do
      allow_nil? true
      public? true
      constraints max_length: 50
    end

    attribute :postal_code, :string do
      allow_nil? true
      public? true
      constraints max_length: 50
    end

    # TODO: Add more attributes related to user profile
    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Fleetms.Accounts.User do
      allow_nil? false
    end
  end

  calculations do
    calculate :full_name, :string, expr((first_name || "") <> " " <> (last_name || ""))
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  identities do
    identity :unique_user_profile, [:user_id]
  end

  postgres do
    table "user_profiles"
    repo Fleetms.Repo
  end
end
