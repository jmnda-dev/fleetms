defmodule Fleetms.Contacts do
  @moduledoc """
  The contacts domain: an organization's address book of external parties —
  vendors, suppliers, insurers, inspectors, towing companies and regulators — with
  their contact details. People and organizations the fleet deals with but who
  aren't users or drivers.
  """
  use Ash.Domain, otp_app: :fleetms, extensions: [AshPhoenix, AshJsonApi.Domain]

  json_api do
    routes do
      base_route "/contacts", Fleetms.Contacts.Contact do
        index :list
        get(:get_by_id)
        post(:create)
        patch(:update)
        patch(:restore, route: "/:id/restore")
        delete(:destroy)
      end
    end
  end

  resources do
    resource Fleetms.Contacts.Contact do
      define :list_contacts, action: :list
      define :list_archived_contacts, action: :list_archived
      define :get_contact, action: :get_by_id, args: [:id]
      define :create_contact, action: :create
      define :update_contact, action: :update
      define :delete_contact, action: :destroy
      define :restore_contact, action: :restore
    end
  end
end
