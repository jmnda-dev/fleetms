defmodule Fleetms.Inspections.InspectionFormVersion do
  @moduledoc """
  An immutable, published snapshot of an inspection form's document.

  Publishing a form freezes its current `draft_schema` into a new version with the
  next per-form `version_number`. Versions are never edited (there is no update
  action) — a change to a form means editing the draft and publishing again, which
  mints a new version. Submissions reference a specific version forever, so a
  historical inspection always renders and reads exactly as it did when taken, no
  matter how the living form later changes.

  Rows are only created via the parent form's `:publish` action (managed through
  the `versions` relationship), never directly.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Inspections,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  import Fleetms.Permissions, only: [has_permission: 1]

  postgres do
    table "inspection_form_versions"
    repo Fleetms.Repo

    references do
      reference :inspection_form, on_delete: :delete
      reference :published_by, on_delete: :nilify
    end
  end

  json_api do
    type "inspection-form-version"
  end

  actions do
    defaults [:read]
    default_accept []

    read :get_by_id do
      get_by :id
      prepare build(load: [inspection_form: [:title]])
    end

    # Invoked only through the form's :publish action via manage_relationship.
    create :create do
      primary? true
      accept [:version_number, :schema]

      change relate_actor(:published_by)
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if has_permission(:view_inspection_forms)
    end

    policy action_type(:create) do
      authorize_if has_permission(:publish_inspection_form)
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id

    attribute :version_number, :integer do
      public? true
      allow_nil? false
      constraints min: 1
      description "Per-form sequential version, starting at 1."
    end

    attribute :schema, Fleetms.Inspections.Schema do
      public? true
      allow_nil? false
      description "The frozen form document at publish time."
    end

    attribute :published_at, :utc_datetime do
      public? true
      allow_nil? false
      default &DateTime.utc_now/0
    end

    timestamps()
  end

  relationships do
    belongs_to :inspection_form, Fleetms.Inspections.InspectionForm do
      allow_nil? false
      public? true
    end

    belongs_to :published_by, Fleetms.Accounts.User do
      domain Fleetms.Accounts
      allow_nil? true
      public? true
      description "The member who published this version (the acting user)."
    end
  end

  identities do
    identity :unique_version_per_form, [:inspection_form_id, :version_number]
  end
end
