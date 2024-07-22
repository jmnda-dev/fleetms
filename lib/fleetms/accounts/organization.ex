defmodule Fleetms.Accounts.Organization do
  @moduledoc """
  Defines the `Fleetms.Accounts.Organization` module, which provides functionality for managing organizations in the FMS application.

  An organization represents a group or entity that uses the FMS application. Organizations have a name, description, phone number, and email address associated with them.

  This module uses the `Ash.Resource` behaviour and the `AshPostgres.DataLayer` data layer to manage organizations in a PostgreSQL database.
  """

  use Ash.Resource,
    domain: Fleetms.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [
      Ash.Policy.Authorizer
    ]

  alias __MODULE__
  @schema_prefix "fleetms_org_"

  def get_schema_prefix, do: @schema_prefix

  defimpl Ash.ToTenant do
    def to_tenant(%{id: id}, _resource) do
      "#{Organization.get_schema_prefix()}#{id}"
    end
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 50
      description "The name of the organization"
    end

    attribute :description, :string do
      allow_nil? true
      public? true
      constraints max_length: 255
      description "A brief description of the organization"
    end

    attribute :phone, :string do
      allow_nil? true
      public? true
      constraints max_length: 20
      description "The phone number of the organization"
    end

    attribute :is_provider, :boolean do
      allow_nil? false
      public? true
      default false
      description "Indicates if the organization is a provider of services."
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  postgres do
    table "organizations"
    repo Fleetms.Repo

    manage_tenant do
      template [@schema_prefix, :id]
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :all
  end

  identities do
    identity :unique_name, [:name] do
      eager_check? true
    end
  end
end
