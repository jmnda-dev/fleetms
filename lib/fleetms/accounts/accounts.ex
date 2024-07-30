defmodule Fleetms.Accounts do
  @moduledoc """
  A Ash domain module for interacting with resources in the Accounts context.
  """
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  resources do
    resource Fleetms.Accounts.Organization do
      define :get_all_tenants, action: :all
    end

    resource Fleetms.Accounts.User do
      define :get_user_by_id, action: :get_by_id, args: [:id]
      define :get_all_users, action: :get_all
      define :list_users, action: :list, args: [
        :paginate_sort_opts,
        :search_query,
        :advanced_filter_params,
        :current_organization_id
      ]
    end

    resource Fleetms.Accounts.UserProfile do
      define :update_profile_photo, action: :set_profile_photo
      define :remove_profile_photo, action: :remove_photo
    end

    resource Fleetms.Accounts.Token
  end

  admin do
    show? true
  end
end
