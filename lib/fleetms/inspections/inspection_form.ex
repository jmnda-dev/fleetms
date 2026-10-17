defmodule Fleetms.Inspections.InspectionForm do
  @moduledoc """
  A living inspection template (e.g. "Daily DVIR").

  The form holds a mutable working document, `draft_schema` (a
  `Fleetms.Inspections.Schema`), which the builder edits. Publishing snapshots that
  draft into an immutable `Fleetms.Inspections.InspectionFormVersion` and marks the
  form active; the draft can then keep evolving for the next version. The form's
  identity and metadata (title, labels, status) live here; the questions themselves
  live entirely inside `draft_schema` as one typed jsonb document, so adding item
  types never touches this resource.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Inspections,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [Fleetms.Permissions.Dsl, AshJsonApi.Resource]

  import Fleetms.Permissions, only: [has_permission: 1]

  alias Fleetms.Inspections.InspectionForm

  @writable_attrs [:title, :description, :labels]

  postgres do
    table "inspection_forms"
    repo Fleetms.Repo

    # The `draft_schema` default (an empty Schema struct) is applied by Ash at
    # create time, not by the database. Declaring no DB-level default keeps
    # codegen from trying to convert a struct into an Ecto column default.
    migration_defaults draft_schema: "nil"
  end

  permissions do
    permission :view_inspection_forms,
      action: :read,
      label: "View Inspection Forms",
      group: "Inspections"

    permission :create_inspection_form,
      action: :create,
      label: "Create Inspection Form",
      group: "Inspections"

    permission :update_inspection_form,
      action: :update,
      label: "Update Inspection Form",
      group: "Inspections"

    permission :publish_inspection_form,
      action: :publish,
      label: "Publish Inspection Form",
      group: "Inspections"

    permission :delete_inspection_form,
      action: :destroy,
      label: "Delete Inspection Form",
      group: "Inspections"
  end

  json_api do
    type "inspection-form"
    includes(versions: [])
  end

  actions do
    defaults [:read]
    default_accept []

    read :get_by_id do
      get_by :id

      prepare build(
                load: [
                  :version_count,
                  :latest_version_number,
                  versions: [:version_number, :published_at]
                ]
              )
    end

    read :list do
      argument :search_query, :string, default: ""
      argument :filters, :map, default: %{}

      argument :sort_by, :atom do
        constraints one_of: [:title, :status, :updated_at, :inserted_at]
        default :updated_at
      end

      argument :sort_order, :atom do
        constraints one_of: [:asc, :desc]
        default :desc
      end

      pagination offset?: true, countable: true, default_limit: 20, max_page_size: 100
      prepare Fleetms.Inspections.InspectionForm.Preparations.ListInspectionForms
    end

    create :create do
      primary? true
      accept @writable_attrs
      # New forms start as an empty draft; the builder fills draft_schema in later.
    end

    create :duplicate do
      accept @writable_attrs ++ [:draft_schema]

      description "Create a new draft form from a copy of an existing form or a starter template."
    end

    update :update do
      primary? true
      require_atomic? false
      accept @writable_attrs ++ [:draft_schema]
      description "Edit the form's metadata and working draft document."
    end

    update :publish do
      require_atomic? false
      description "Freeze the current draft into a new immutable version and activate the form."

      change InspectionForm.Changes.PublishVersion
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
      authorize_if has_permission(:view_inspection_forms)
    end

    policy action([:create, :duplicate]) do
      authorize_if has_permission(:create_inspection_form)
    end

    policy action(:update) do
      authorize_if has_permission(:update_inspection_form)
    end

    policy action(:publish) do
      authorize_if has_permission(:publish_inspection_form)
    end

    policy action_type(:destroy) do
      authorize_if has_permission(:delete_inspection_form)
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      public? true
      allow_nil? false
      constraints min_length: 1, max_length: 100
    end

    attribute :description, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :status, :atom do
      public? true
      allow_nil? false
      default :draft
      constraints one_of: [:draft, :active, :archived]
      writable? false

      description "Set by lifecycle actions (:draft on create, :active on publish), not edited directly."
    end

    attribute :labels, {:array, :string} do
      public? true
      allow_nil? false
      default []
    end

    attribute :draft_schema, Fleetms.Inspections.Schema do
      public? true
      allow_nil? false
      default %{}
      description "The mutable working document edited by the builder."
    end

    timestamps()
  end

  relationships do
    has_many :versions, Fleetms.Inspections.InspectionFormVersion do
      public? true
      sort version_number: :desc
    end
  end

  aggregates do
    count :version_count, :versions
    max :latest_version_number, :versions, :version_number
  end

  identities do
    identity :unique_title, [:title]
  end
end
