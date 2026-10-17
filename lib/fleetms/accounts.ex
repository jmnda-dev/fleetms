defmodule Fleetms.Accounts do
  use Ash.Domain, otp_app: :fleetms, extensions: [AshAdmin.Domain, AshPhoenix, AshJsonApi.Domain]

  admin do
    show? true
  end

  # Org-level role management over the API. Platform provisioning (organizations,
  # users, the individuals pool) is deliberately NOT exposed. Roles and user-roles
  # are tenant-scoped, so they stay within the current org; the permission catalog
  # is a global, read-only reference.
  json_api do
    routes do
      base_route "/roles", Fleetms.Accounts.Role do
        index :read
        get(:get_by_id)
        post(:create)
        patch(:update)
        patch(:set_permissions, route: "/:id/permissions")
        delete(:destroy)
      end

      base_route "/user-roles", Fleetms.Accounts.UserRole do
        index :read
        post(:assign)
        delete(:revoke)
      end

      base_route "/permissions", Fleetms.Accounts.Permission do
        index :read
        get(:read)
      end

      base_route "/user-profiles", Fleetms.Accounts.UserProfile do
        index :read
        get(:read)
        post(:create)
        patch(:update)
      end
    end
  end

  resources do
    resource Fleetms.Accounts.Token

    resource Fleetms.Accounts.ApiKey do
      define :create_api_key, action: :create
      define :list_user_api_keys, action: :list_for_user, args: [:user_id]
      define :delete_api_key, action: :destroy
    end

    resource Fleetms.Accounts.User do
      define :list_users, action: :read
      define :get_user, action: :read, get_by: [:id]
      define :get_user_by_email, action: :get_by_email, args: [:email]
      define :create_member_with_username, action: :create_member_with_username
      define :create_client_account, action: :create_client_account
      define :register_via_invitation, action: :register_via_invitation
      define :change_password, action: :change_password
      define :set_last_organization, action: :set_last_organization
    end

    resource Fleetms.Accounts.UserProfile do
      define :get_user_profile, action: :read, get_by: [:user_id]
      define :create_user_profile, action: :create
      define :update_user_profile, action: :update
    end

    resource Fleetms.Accounts.Invitation do
      define :get_invitation_by_token, action: :get_by_token, args: [:token]
      define :create_invitation, action: :invite
      define :accept_invitation, action: :accept
      define :revoke_invitation, action: :revoke
    end

    resource Fleetms.Accounts.Organization do
      define :create_organization, action: :create, args: [:name]
      define :list_organizations, action: :read
      define :get_organization, action: :get_by_id, args: [:id]
      define :get_organization_by_public_id, action: :read, get_by: [:public_id]
      define :update_organization_settings, action: :update_settings
      define :suspend_organization, action: :suspend
      define :reactivate_organization, action: :reactivate
    end

    resource Fleetms.Accounts.ClientProfile do
      define :create_client_profile, action: :create
      define :list_client_profiles, action: :read
      define :get_client_profile, action: :get_for_organization, args: [:organization_id]
      define :get_client_profile_for_owner, action: :get_for_owner, args: [:owner_id]
      define :list_individual_clients, action: :list_individuals
      define :update_client_profile, action: :update
      define :verify_client_profile, action: :verify
      define :reject_client_profile, action: :reject
    end

    resource Fleetms.Accounts.UserOrganization do
      define :add_user_to_organization, action: :create
      define :list_user_organizations, action: :read
      define :suspend_membership, action: :suspend
      define :reactivate_membership, action: :reactivate
      define :remove_membership, action: :destroy
    end

    resource Fleetms.Accounts.Permission do
      define :list_permissions, action: :read
    end

    resource Fleetms.Accounts.Role do
      define :list_roles, action: :read
      define :get_role, action: :get_by_id, args: [:id]
      define :create_role, action: :create
      define :update_role, action: :update
      define :delete_role, action: :destroy
      define :set_role_permissions, action: :set_permissions
    end

    resource Fleetms.Accounts.RolePermission

    resource Fleetms.Accounts.UserRole do
      define :list_user_roles, action: :read
      define :assign_user_role, action: :assign
      define :revoke_user_role, action: :revoke
    end

    resource Fleetms.Accounts.PlatformAccessLog do
      define :record_platform_access, action: :record
      define :list_platform_access_logs, action: :list
    end
  end
end
