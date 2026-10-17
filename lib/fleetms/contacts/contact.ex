defmodule Fleetms.Contacts.Contact do
  @moduledoc """
  An external party the fleet deals with: a vendor rep, an insurer, an inspection
  officer, a parts supplier, a towing company, a regulator, and so on.

  A plain address book — a name, who they represent, how to reach them and a note.
  It isn't a user (no login) and isn't a driver (doesn't operate vehicles); it's
  the "who do I call about this" list that every operation ends up needing.
  Soft-deleted (AshArchival) like the other operational records.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Contacts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [Fleetms.Permissions.Dsl, AshArchival.Resource, AshJsonApi.Resource],
    # Owner-scopes contacts for the individuals pool (owner_id + stamp + read filter).
    fragments: [Fleetms.Owned]

  import Fleetms.Permissions, only: [has_permission: 1]

  alias Fleetms.Contacts

  @writable_attrs [
    :name,
    :company,
    :title,
    :contact_type,
    :phone,
    :email,
    :notes
  ]

  postgres do
    table "contacts"
    repo Fleetms.Repo
  end

  permissions do
    permission :view_contacts, action: :read, label: "View Contacts", group: "Contacts"
    permission :create_contact, action: :create, label: "Create Contact", group: "Contacts"
    permission :update_contact, action: :update, label: "Update Contact", group: "Contacts"
    permission :delete_contact, action: :destroy, label: "Delete Contact", group: "Contacts"
  end

  archive do
    exclude_read_actions([:list_archived])
  end

  json_api do
    type "contact"
  end

  actions do
    defaults [:read, :destroy]
    default_accept []

    read :get_by_id do
      get_by :id
    end

    read :list do
      argument :search_query, :string, default: ""

      argument :contact_type, Contacts.ContactType do
        allow_nil? true
      end

      argument :sort_by, :atom do
        default :name
        constraints one_of: [:name, :company, :contact_type, :inserted_at]
      end

      argument :sort_order, :atom do
        default :asc
        constraints one_of: [:asc, :desc]
      end

      pagination offset?: true, countable: true, default_limit: 20, max_page_size: 100

      prepare Contacts.Contact.Preparations.ListContacts
    end

    read :list_archived do
      argument :search_query, :string, default: ""

      pagination offset?: true, countable: true, default_limit: 20, max_page_size: 100

      filter expr(not is_nil(archived_at))
      prepare Contacts.Contact.Preparations.ListContacts
    end

    create :create do
      primary? true
      accept @writable_attrs
    end

    update :update do
      primary? true
      require_atomic? false
      accept @writable_attrs
    end

    update :restore do
      require_atomic? false
      change set_attribute(:archived_at, nil)
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if has_permission(:view_contacts)
    end

    policy action_type(:create) do
      authorize_if has_permission(:create_contact)
    end

    policy action_type(:update) do
      authorize_if has_permission(:update_contact)
    end

    policy action_type(:destroy) do
      authorize_if has_permission(:delete_contact)
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 150
      description "The contact's name — a person or an organization."
    end

    attribute :company, :string do
      public? true
      constraints max_length: 150
      description "The company or organization they belong to, if the name is a person."
    end

    attribute :title, :string do
      public? true
      constraints max_length: 100
      description "Their role or job title (e.g. Parts Manager, Claims Officer)."
    end

    attribute :contact_type, Contacts.ContactType do
      allow_nil? false
      public? true
      default :other
    end

    attribute :phone, :string do
      public? true
      constraints max_length: 50
    end

    attribute :email, :string do
      public? true
      constraints max_length: 160
    end

    attribute :notes, :string do
      public? true
      constraints max_length: 2000
    end

    timestamps()
  end
end
