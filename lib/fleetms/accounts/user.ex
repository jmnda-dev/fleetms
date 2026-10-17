defmodule Fleetms.Accounts.User do
  @moduledoc """
  A person who can sign in. Users authenticate with a password, belong to one or
  more organizations, and carry the roles that determine their permissions.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication]

  authentication do
    add_ons do
      log_out_everywhere do
        apply_on_password_change? true
      end

      confirmation :confirm_new_user do
        monitor_fields [:email]
        confirm_on_create? true
        confirm_on_update? false
        require_interaction? true
        confirmed_at_field :confirmed_at

        auto_confirm_actions [
          :sign_in_with_magic_link,
          :reset_password_with_token,
          # Accepting an emailed invitation already proves email ownership, so
          # don't send a separate confirmation email.
          :register_via_invitation
        ]

        sender Fleetms.Accounts.User.Senders.SendNewUserConfirmationEmail
      end
    end

    tokens do
      enabled? true
      token_resource Fleetms.Accounts.Token
      signing_secret Fleetms.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
    end

    strategies do
      password :password do
        identity_field :email
        hash_provider AshAuthentication.BcryptProvider

        # Block sign-in until the user's email has been confirmed. The
        # confirmation email is sent on registration by the `confirm_new_user`
        # add-on. Surfaces `AshAuthentication.Errors.UnconfirmedUser` on a
        # blocked sign-in, which AuthController turns into a flash message.
        require_confirmed_with :confirmed_at

        resettable do
          sender Fleetms.Accounts.User.Senders.SendPasswordResetEmail
          # these configurations will be the default in a future release
          password_reset_action_name :reset_password_with_token
          request_password_reset_action_name :request_password_reset_token
        end
      end

      # Username + password for admin-provisioned users who have no email. No
      # self-registration and no email-based reset (an admin resets their
      # password); these users are auto-confirmed on creation.
      password :username_password do
        identity_field :username
        hash_provider AshAuthentication.BcryptProvider
        registration_enabled? false
        sign_in_action_name :sign_in_with_username
      end

      remember_me :remember_me

      magic_link do
        identity_field :email
        registration_enabled? true
        require_interaction? true

        sender Fleetms.Accounts.User.Senders.SendMagicLinkEmail
      end

      # Long-lived keys for server-to-server access to the JSON:API. A key
      # authenticates the user; the tenant is still the per-request org header.
      api_key do
        api_key_relationship :valid_api_keys
        api_key_hash_attribute :api_key_hash
      end
    end
  end

  postgres do
    table "users"
    repo Fleetms.Repo

    references do
      reference :last_organization, on_delete: :nilify
    end

    check_constraints do
      check_constraint [:email, :username],
        check: "email IS NOT NULL OR username IS NOT NULL",
        name: "users_email_or_username_present",
        message: "must have either an email or a username"
    end

    identity_wheres_to_sql unique_username: "username IS NOT NULL"
  end

  actions do
    defaults [:read]

    update :set_last_organization do
      description "Remembers the organization a user most recently signed into."
      accept [:last_organization_id]
    end

    read :get_by_subject do
      description "Get a user by the subject claim in a JWT"
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
    end

    update :change_password do
      # Use this action to allow users to change their password by providing
      # their current password and a new password.

      require_atomic? false
      accept []
      argument :current_password, :string, sensitive?: true, allow_nil?: false

      argument :password, :string,
        sensitive?: true,
        allow_nil?: false,
        constraints: [min_length: 8]

      argument :password_confirmation, :string, sensitive?: true, allow_nil?: false

      validate confirm(:password, :password_confirmation)

      validate {AshAuthentication.Strategy.Password.PasswordValidation,
                strategy_name: :password, password_argument: :current_password}

      change {AshAuthentication.Strategy.Password.HashPasswordChange, strategy_name: :password}
    end

    read :sign_in_with_password do
      description "Attempt to sign in using a email and password."
      get? true

      argument :email, :ci_string do
        description "The email to use for retrieving the user."
        allow_nil? false
      end

      argument :password, :string do
        description "The password to check for the matching user."
        allow_nil? false
        sensitive? true
      end

      # validates the provided email and password and generates a token
      prepare AshAuthentication.Strategy.Password.SignInPreparation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    read :sign_in_with_api_key do
      description "Authenticate a request presenting a valid API key."
      argument :api_key, :string, allow_nil?: false, sensitive?: true
      prepare AshAuthentication.Strategy.ApiKey.SignInPreparation
    end

    read :sign_in_with_token do
      # In the generated sign in components, we validate the
      # email and password directly in the LiveView
      # and generate a short-lived token that can be used to sign in over
      # a standard controller action, exchanging it for a standard token.
      # This action performs that exchange. If you do not use the generated
      # liveviews, you may remove this action, and set
      # `sign_in_tokens_enabled? false` in the password strategy.

      description "Attempt to sign in using a short-lived sign in token."
      get? true

      argument :token, :string do
        description "The short-lived sign in token."
        allow_nil? false
        sensitive? true
      end

      # validates the provided sign in token and generates a token
      prepare AshAuthentication.Strategy.Password.SignInWithTokenPreparation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    create :register_with_password do
      description "Register a new user with a email and password."

      argument :email, :ci_string do
        allow_nil? false
      end

      argument :password, :string do
        description "The proposed password for the user, in plain text."
        allow_nil? false
        constraints min_length: 8
        sensitive? true
      end

      argument :password_confirmation, :string do
        description "The proposed password for the user (again), in plain text."
        allow_nil? false
        sensitive? true
      end

      # Sets the email from the argument
      change set_attribute(:email, arg(:email))

      # Hashes the provided password
      change AshAuthentication.Strategy.Password.HashPasswordChange

      # Generates an authentication token for the user
      change AshAuthentication.GenerateTokenChange

      # validates that the password matches the confirmation
      validate AshAuthentication.Strategy.Password.PasswordConfirmationValidation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    create :create_member_with_username do
      description "Admin-provisioned user identified by a username, with no email."

      argument :username, :string, allow_nil?: false

      argument :password, :string,
        allow_nil?: false,
        sensitive?: true,
        constraints: [min_length: 8]

      argument :password_confirmation, :string, allow_nil?: false, sensitive?: true
      argument :profile, :map, allow_nil?: false

      change set_attribute(:username, arg(:username))
      # Trusted (admin-created) and email-less: confirmed on creation so the
      # confirmation gate never blocks them.
      change set_attribute(:confirmed_at, &DateTime.utc_now/0)
      change manage_relationship(:profile, :profile, type: :create)

      change {AshAuthentication.Strategy.Password.HashPasswordChange,
              strategy_name: :username_password}

      validate {AshAuthentication.Strategy.Password.PasswordConfirmationValidation,
                strategy_name: :username_password}
    end

    create :create_client_account do
      description "Eagerly provisions an email account for a managed individual client. No password is set — the client sets one later via reset, or signs in by magic link. Created by trusted platform staff (from KYC), so it is confirmed on creation and the confirmation gate never blocks them."

      argument :email, :ci_string, allow_nil?: false
      argument :profile, :map, allow_nil?: false

      change set_attribute(:email, arg(:email))
      change set_attribute(:confirmed_at, &DateTime.utc_now/0)
      change manage_relationship(:profile, :profile, type: :create)
    end

    create :register_via_invitation do
      description "Creates an account for an invited email, set up by the invitee."

      argument :email, :ci_string, allow_nil?: false

      argument :password, :string,
        allow_nil?: false,
        sensitive?: true,
        constraints: [min_length: 8]

      argument :password_confirmation, :string, allow_nil?: false, sensitive?: true
      argument :profile, :map, allow_nil?: false

      change set_attribute(:email, arg(:email))
      # Accepting an emailed invitation proves ownership of the address.
      change set_attribute(:confirmed_at, &DateTime.utc_now/0)
      change manage_relationship(:profile, :profile, type: :create)
      change {AshAuthentication.Strategy.Password.HashPasswordChange, strategy_name: :password}

      validate {AshAuthentication.Strategy.Password.PasswordConfirmationValidation,
                strategy_name: :password}
    end

    action :request_password_reset_token do
      description "Send password reset instructions to a user if they exist."

      argument :email, :ci_string do
        allow_nil? false
      end

      # creates a reset token and invokes the relevant senders
      run {AshAuthentication.Strategy.Password.RequestPasswordReset, action: :get_by_email}
    end

    read :get_by_email do
      description "Looks up a user by their email"
      get_by :email
    end

    update :reset_password_with_token do
      argument :reset_token, :string do
        allow_nil? false
        sensitive? true
      end

      argument :password, :string do
        description "The proposed password for the user, in plain text."
        allow_nil? false
        constraints min_length: 8
        sensitive? true
      end

      argument :password_confirmation, :string do
        description "The proposed password for the user (again), in plain text."
        allow_nil? false
        sensitive? true
      end

      # validates the provided reset token
      validate AshAuthentication.Strategy.Password.ResetTokenValidation

      # validates that the password matches the confirmation
      validate AshAuthentication.Strategy.Password.PasswordConfirmationValidation

      # Hashes the provided password
      change AshAuthentication.Strategy.Password.HashPasswordChange

      # Generates an authentication token for the user
      change AshAuthentication.GenerateTokenChange
    end

    create :sign_in_with_magic_link do
      description "Sign in or register a user with magic link."

      argument :token, :string do
        description "The token from the magic link that was sent to the user"
        allow_nil? false
      end

      argument :remember_me, :boolean do
        description "Whether to generate a remember me token"
        allow_nil? true
      end

      upsert? true
      upsert_identity :unique_email
      upsert_fields [:email]

      # Uses the information from the token to create or sign in the user
      change AshAuthentication.Strategy.MagicLink.SignInChange

      change {AshAuthentication.Strategy.RememberMe.MaybeGenerateTokenChange,
              strategy_name: :remember_me}

      metadata :token, :string do
        allow_nil? false
      end
    end

    action :request_magic_link do
      argument :email, :ci_string do
        allow_nil? false
      end

      run AshAuthentication.Strategy.MagicLink.Request
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    # A user may read themselves and anyone who shares an organization with them
    # (e.g. listing the members of their organization).
    policy action_type(:read) do
      authorize_if expr(id == ^actor(:id))
      authorize_if expr(exists(organizations.users, id == ^actor(:id)))
    end

    # A user may only update their own "last organization" preference.
    policy action(:set_last_organization) do
      authorize_if expr(id == ^actor(:id))
    end

    # A user may change their own password.
    policy action(:change_password) do
      authorize_if expr(id == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id

    # A user must have at least one of email / username (enforced by a check
    # constraint and a validation). Email is for self-registered and invited
    # users; username is for admin-provisioned users who have no email.
    attribute :email, :ci_string do
      allow_nil? true
      public? true
    end

    # Opaque global login handle for admin-provisioned users with no email.
    # Unique-if-present (Postgres treats NULLs as distinct).
    attribute :username, :string do
      allow_nil? true
      public? true
      constraints min_length: 3, max_length: 30, match: ~r/^[a-zA-Z0-9_.-]+$/
    end

    attribute :hashed_password, :string do
      sensitive? true
    end

    attribute :confirmed_at, :utc_datetime_usec

    # Platform-level super administrator. Bypasses all permission checks
    # everywhere. Must only be settable by a root-level admin, never via the
    # tenant-scoped API.
    #
    # `writable? false` blocks all changeset writes (mass-assignment, accidental
    # `set_attribute`, etc.). Granting super-admin must be a deliberate code-level
    # operation via `Ash.Changeset.force_change_attribute(changeset, :is_super_admin, true)`.
    attribute :is_super_admin, :boolean do
      allow_nil? false
      default false
      writable? false
    end
  end

  relationships do
    has_one :profile, Fleetms.Accounts.UserProfile

    has_many :user_organizations, Fleetms.Accounts.UserOrganization

    has_many :valid_api_keys, Fleetms.Accounts.ApiKey do
      filter expr(valid)
    end

    many_to_many :organizations, Fleetms.Accounts.Organization do
      through Fleetms.Accounts.UserOrganization
      source_attribute_on_join_resource :user_id
      destination_attribute_on_join_resource :organization_id
    end

    # The organization the user most recently signed into, used to land them
    # back in the right place after login. Nullable; cleared if the org is deleted.
    belongs_to :last_organization, Fleetms.Accounts.Organization do
      attribute_type :uuid
      allow_nil? true
    end
  end

  identities do
    identity :unique_email, [:email]

    identity :unique_username, [:username] do
      # NULL usernames are distinct in Postgres, so this only constrains users
      # that actually have one.
      where expr(not is_nil(username))
    end
  end
end
