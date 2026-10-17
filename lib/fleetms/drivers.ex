defmodule Fleetms.Drivers do
  @moduledoc """
  The drivers domain: the people who operate the fleet's vehicles without needing
  an app login, along with their contact details and driving-licence expiry.
  """
  use Ash.Domain, otp_app: :fleetms, extensions: [AshPhoenix, AshJsonApi.Domain]

  json_api do
    routes do
      base_route "/drivers", Fleetms.Drivers.Driver do
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
    resource Fleetms.Drivers.Driver do
      define :list_drivers, action: :list
      define :list_archived_drivers, action: :list_archived
      define :get_driver, action: :get_by_id, args: [:id]
      define :create_driver, action: :create
      define :update_driver, action: :update
      define :delete_driver, action: :destroy
      define :restore_driver, action: :restore
    end
  end
end
