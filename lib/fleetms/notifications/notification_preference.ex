defmodule Fleetms.Notifications.NotificationPreference do
  @moduledoc """
  A member's in-app notification preferences within an organization — which
  categories of notification they want to receive on the bell.

  One row per user per org (tenant-scoped). A missing row means "subscribed to
  everything", so the defaults are all `true` and the gate in
  `Fleetms.Notifications.notify_if_subscribed/2` treats absence as opted-in.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Notifications,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "notification_preferences"
    repo Fleetms.Repo

    references do
      reference :user, on_delete: :delete
    end
  end

  actions do
    defaults [:read]
    default_accept []

    # The acting member's own preferences (one row), by user id.
    read :get_for_user do
      get_by :user_id
    end

    # Create-or-update the member's preferences in one call (the settings form).
    create :upsert do
      primary? true
      accept [:user_id, :issues, :comments, :inspections]
      upsert? true
      upsert_identity :unique_user
      upsert_fields [:issues, :comments, :inspections]
    end

    update :update do
      primary? true
      accept [:issues, :comments, :inspections]
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    # A member only reads and writes their own preferences.
    policy action_type([:read, :update]) do
      authorize_if expr(user_id == ^actor(:id))
    end

    policy action(:upsert) do
      authorize_if expr(user_id == ^actor(:id))
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id

    attribute :issues, :boolean, allow_nil?: false, default: true, public?: true
    attribute :comments, :boolean, allow_nil?: false, default: true, public?: true
    attribute :inspections, :boolean, allow_nil?: false, default: true, public?: true

    timestamps()
  end

  relationships do
    belongs_to :user, Fleetms.Accounts.User do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_user, [:user_id]
  end
end
