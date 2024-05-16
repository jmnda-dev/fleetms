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

    attribute :phone_number, :string do
      allow_nil? true
      public? true
      constraints min_length: 10, max_length: 18
    end

    attribute :secondary_phone_number, :string do
      allow_nil? true
      public? true
      constraints min_length: 10, max_length: 18
    end

    attribute :date_of_birth, :date do
      allow_nil? true
      public? true
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

    attribute :profile_photo, :string do
      allow_nil? true
      public? true
      writable? false
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

    update :set_profile_photo do
      require_atomic? false

      argument :profile_photo, :string do
        allow_nil? false
      end

      change fn changeset, _context ->
        Ash.Changeset.force_change_attribute(
          changeset,
          :profile_photo,
          changeset.arguments.profile_photo
        )
      end
    end

    update :remove_photo do
      require_atomic? false

      change fn changeset, _context ->
        Ash.Changeset.force_change_attribute(
          changeset,
          :profile_photo,
          nil
        )
        |> Ash.Changeset.after_action(fn changeset, updated_user_profile ->
          photo = Ash.Changeset.get_data(changeset, :profile_photo)
          Fleetms.UserProfilePhoto.delete({photo, updated_user_profile})

          {:ok, updated_user_profile}
        end)
      end
    end
  end

  identities do
    identity :unique_user_profile, [:user_id]
  end

  postgres do
    table "user_profiles"
    repo Fleetms.Repo
  end
end
