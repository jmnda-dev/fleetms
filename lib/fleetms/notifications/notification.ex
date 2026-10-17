defmodule Fleetms.Notifications.Notification do
  @moduledoc """
  An in-app notification for a member within an organization — "you were assigned
  issue #12", "3 renewals are due", and so on.

  Notifications are tenant-scoped (they live in the org's schema) and addressed to
  a `recipient`. Creating one broadcasts a signal on the recipient's topic so a
  connected LiveView (the navbar bell) updates in real time. A member only ever
  sees and manages their own notifications.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Notifications,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  require Ash.Query

  postgres do
    table "notifications"
    repo Fleetms.Repo

    references do
      reference :recipient, on_delete: :delete
      reference :actor, on_delete: :nilify
    end
  end

  json_api do
    type "notification"
  end

  actions do
    defaults [:read, :destroy]
    default_accept []

    read :get_by_id do
      get_by :id
    end

    # The recipient's notifications, newest first. The policy restricts rows to the
    # actor, so this never needs an explicit recipient filter.
    read :list do
      prepare build(sort: [inserted_at: :desc])
    end

    read :list_unread do
      filter expr(is_nil(read_at))
      prepare build(sort: [inserted_at: :desc])
    end

    create :notify do
      primary? true
      accept [:recipient_id, :actor_id, :type, :title, :body, :path]

      change Fleetms.Notifications.Notification.Changes.Broadcast
    end

    update :mark_read do
      change set_attribute(:read_at, &DateTime.utc_now/0)
    end

    # Count the actor's unread notifications (for the bell badge).
    action :unread_count, :integer do
      run fn _input, context ->
        count =
          __MODULE__
          |> Ash.Query.filter(recipient_id == ^context.actor.id and is_nil(read_at))
          |> Ash.count!(tenant: context.tenant, authorize?: false)

        {:ok, count}
      end
    end

    # Mark all of the actor's unread notifications as read; returns how many.
    action :mark_all_read, :integer do
      run fn _input, context ->
        %{records: records} =
          __MODULE__
          |> Ash.Query.filter(recipient_id == ^context.actor.id and is_nil(read_at))
          |> Ash.bulk_update!(:mark_read, %{},
            tenant: context.tenant,
            actor: context.actor,
            authorize?: false,
            return_records?: true,
            strategy: :stream
          )

        {:ok, length(records)}
      end
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    # A member only sees/manages their own notifications.
    policy action_type([:read, :update, :destroy]) do
      authorize_if expr(recipient_id == ^actor(:id))
    end

    # Created server-side (by producers/jobs) — the creator is rarely the recipient.
    policy action(:notify) do
      authorize_if always()
    end

    # Generic actions filter to the actor internally.
    policy action([:unread_count, :mark_all_read]) do
      authorize_if always()
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id

    attribute :type, :string do
      public? true
      constraints max_length: 50
      description "Producer category, e.g. \"issue_assigned\" — drives the icon."
    end

    attribute :title, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 255
    end

    attribute :body, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :path, :string do
      public? true
      constraints max_length: 500

      description """
      Where the bell links to, relative to the org root (e.g. "/issues/<id>").
      The bell prefixes it with the recipient's current "/o/<public_id>" scope,
      since notifications are only ever viewed within their own organization.
      """
    end

    attribute :read_at, :utc_datetime, public?: true

    timestamps()
  end

  relationships do
    belongs_to :recipient, Fleetms.Accounts.User do
      domain Fleetms.Accounts
      allow_nil? false
      public? true
      attribute_writable? true
    end

    belongs_to :actor, Fleetms.Accounts.User do
      domain Fleetms.Accounts
      allow_nil? true
      public? true
      attribute_writable? true
      description "The member whose action produced the notification, if any."
    end
  end
end
