defmodule Fleetms.Accounts.UserProfile do
  @moduledoc """
  A user's personal details (name, contact, address). Global — lives in the public
  schema and describes the person, not their role in any one organization. One
  profile per user.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  json_api do
    type "user-profile"
  end

  postgres do
    table "user_profiles"
    repo Fleetms.Repo

    references do
      reference :user, on_delete: :delete
    end
  end

  @editable_fields [
    :first_name,
    :last_name,
    :other_name,
    :phone_number,
    :secondary_phone_number,
    :date_of_birth,
    :address,
    :city,
    :state,
    :postal_code
  ]

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:user_id | @editable_fields]
    end

    update :update do
      primary? true
      accept @editable_fields
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    # A user may read/update their own profile, and read the profiles of people
    # who share an organization with them.
    policy action_type([:update, :destroy]) do
      authorize_if expr(user_id == ^actor(:id))
    end

    policy action_type(:read) do
      authorize_if expr(user_id == ^actor(:id))
      authorize_if expr(exists(user.organizations.users, id == ^actor(:id)))
    end

    policy action_type(:create) do
      authorize_if expr(user_id == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :first_name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :last_name, :string do
      public? true
      constraints max_length: 100
    end

    attribute :other_name, :string do
      public? true
      constraints max_length: 100
    end

    attribute :phone_number, :string do
      public? true
      constraints min_length: 7, max_length: 18
    end

    attribute :secondary_phone_number, :string do
      public? true
      constraints min_length: 7, max_length: 18
    end

    attribute :date_of_birth, :date, public?: true

    attribute :address, :string do
      public? true
      constraints max_length: 500
    end

    attribute :city, :string do
      public? true
      constraints max_length: 50
    end

    attribute :state, :string do
      public? true
      constraints max_length: 50
    end

    attribute :postal_code, :string do
      public? true
      constraints max_length: 50
    end

    # Stored path/URL to an uploaded avatar; upload handling comes with the
    # settings/profile UI.
    attribute :profile_photo, :string, public?: true

    timestamps()
  end

  relationships do
    belongs_to :user, Fleetms.Accounts.User do
      allow_nil? false
      attribute_writable? true
      attribute_public? true
    end
  end

  calculations do
    calculate :full_name,
              :string,
              expr(
                trim(
                  coalesce(first_name, "") <>
                    " " <> coalesce(last_name, "")
                )
              )
  end

  identities do
    identity :unique_user_profile, [:user_id]
  end
end
