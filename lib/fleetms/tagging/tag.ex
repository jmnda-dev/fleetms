defmodule Fleetms.Tagging.Tag do
  @moduledoc """
  A named, coloured label an organization defines once and reuses across records. Tags
  are the shared vocabulary; they attach to records through `Fleetms.Tagging.Tagging`.

  Names are unique per organization (case-insensitive), so typing the same word always
  resolves to the same tag rather than fragmenting into near-duplicates. A tag is plain
  vocabulary, so it is hard-deleted (not archived); deleting one removes its attachments.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Tagging,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [Fleetms.Permissions.Dsl, AshJsonApi.Resource]

  import Fleetms.Permissions, only: [has_permission: 1]

  postgres do
    table "tags"
    repo Fleetms.Repo
  end

  permissions do
    permission :view_tags,
      action: :read,
      label: "View Tags",
      group: "Tags"

    permission :create_tag,
      action: :create,
      label: "Create Tags",
      group: "Tags"

    permission :update_tag,
      action: :update,
      label: "Edit Tags",
      group: "Tags"

    permission :delete_tags,
      action: :destroy,
      label: "Delete Tags",
      group: "Tags"
  end

  json_api do
    type "tag"
  end

  actions do
    defaults [:read]
    default_accept []

    # The whole vocabulary — for the management page and pickers.
    read :list do
      argument :search_query, :string, default: ""
      argument :filters, :map, default: %{}

      argument :sort_by, :atom do
        constraints one_of: [:name, :color, :usage_count, :inserted_at]
        default :name
      end

      argument :sort_order, :atom do
        constraints one_of: [:asc, :desc]
        default :asc
      end

      pagination offset?: true,
                 countable: true,
                 default_limit: 20,
                 max_page_size: 100,
                 required?: false

      prepare Fleetms.Tagging.Tag.Preparations.ListTags
    end

    create :create do
      primary? true
      accept [:name, :color]

      # Reuse an existing tag with the same name instead of failing on the identity,
      # so "create on the fly" from a record's tag field is idempotent.
      upsert? true
      upsert_identity :unique_name

      change Fleetms.Tagging.Tag.Changes.AssignColor
    end

    update :update do
      primary? true
      accept [:name, :color]
    end

    destroy :destroy do
      primary? true
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if has_permission(:view_tags)
    end

    policy action(:create) do
      authorize_if has_permission(:create_tag)
    end

    policy action(:update) do
      authorize_if has_permission(:update_tag)
    end

    policy action_type(:destroy) do
      authorize_if has_permission(:delete_tags)
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :ci_string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 50, trim?: true
    end

    attribute :color, Fleetms.Tagging.TagColor do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    has_many :taggings, Fleetms.Tagging.Tagging
  end

  aggregates do
    # How many records currently carry this tag — shown on the management page.
    count :usage_count, :taggings
  end

  identities do
    identity :unique_name, [:name]
  end
end
