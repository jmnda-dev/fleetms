defmodule Fleetms.Provisioning do
  @moduledoc """
  Platform-staff onboarding of a managed-service client.

  Provisioning is a staff-only operation that records the KYC `ClientProfile` and
  adds the client's primary contact as a **non-owner `Client` member** — the
  restricted role that can view their fleet and reports and raise issues, while
  platform staff manage the org via the `is_super_admin` bypass. The client is
  deliberately *not* an owner: an owner bypasses every permission check, which
  would defeat the Client role.

  The two client shapes differ only in their container:

    * **Business** — its own organization (and tenant schema); the acting staff
      member is the org's owner, the contact is invited (a new email gets an
      invitation, an existing account is added directly), and the ClientProfile
      is owner-less (one per org).

    * **Individual** — no new org: they join the shared **individuals pool**. Their
      account is created up front (passwordless, confirmed) so `owner_id` exists
      and staff can manage their fleet immediately; they're added as a Client
      member; and their ClientProfile is scoped to them (`owner_id`). Their fleet
      records are isolated inside the pool by that `owner_id` (see
      `Fleetms.Individuals`).
  """

  require Ash.Query

  alias Fleetms.Accounts
  alias Fleetms.Accounts.{Role, User}

  @doc """
  Provisions a client end to end. `staff` must be a platform super-admin.

  `attrs` (string- or atom-keyed):

    * `:name` — organization name (required)
    * `:account_type` — `:business` (default) or `:individual`
    * `:client_email` — the primary contact's email; they receive an invitation
      to set their password (required)
    * KYC: `:contact_name` (required), `:contact_email`, `:contact_phone`,
      `:address`, `:reg_number`, `:notes`

  Returns `{:ok, %{organization:, client_profile:, invite:}}` or
  `{:error, reason}`. The invite is `{:invited, invitation}` for a brand-new
  email, or `{:added, membership}` when the email already has an account.
  """
  @spec provision_client(map(), User.t()) :: {:ok, map()} | {:error, term()}
  def provision_client(attrs, %User{is_super_admin: true} = staff) do
    attrs = normalize(attrs)

    with :ok <- validate(attrs) do
      case account_type(attrs) do
        :individual ->
          # Guarded by the feature flag: with the individual workflow off, only
          # businesses (own org/schema) are provisioned. Defense-in-depth — the
          # provisioning form doesn't offer "Individual" when the flag is off.
          if Fleetms.FeatureFlags.individual_registration?() do
            provision_individual(attrs, staff)
          else
            {:error, :individual_registration_disabled}
          end

        :business ->
          provision_business(attrs, staff)
      end
    end
  end

  def provision_client(_attrs, _staff), do: {:error, :forbidden}

  # A corporate client: its own organization + schema, with the primary contact
  # invited as a Client member (a new email gets an invitation; an existing
  # account is added directly). One owner-less ClientProfile for the org.
  defp provision_business(attrs, staff) do
    with {:ok, org} <- create_org(attrs, staff),
         {:ok, invite} <- invite_client(org, attrs, staff),
         {:ok, profile} <- create_profile(org, attrs, staff) do
      {:ok, %{organization: org, client_profile: profile, invite: invite}}
    end
  end

  # An individual client: no new org — they join the shared individuals pool. Their
  # account is created up front (so owner_id exists and staff can manage their fleet
  # immediately), added as a Client member, and given an owner-scoped ClientProfile.
  defp provision_individual(attrs, staff) do
    pool = Fleetms.Individuals.ensure_pool!(staff)

    with {:ok, {status, client}} <- resolve_client_user(attrs),
         {:ok, _member} <- invite_client(pool, attrs, staff),
         {:ok, profile} <- create_profile(pool, attrs, staff, client.id) do
      {:ok,
       %{organization: pool, client_profile: profile, client_user: client, invite: {status, client}}}
    end
  end

  # Reuse an existing account for this email, or eagerly create a passwordless one.
  defp resolve_client_user(attrs) do
    case Accounts.get_user_by_email(attrs[:client_email], authorize?: false, not_found_error?: false) do
      {:ok, %User{} = user} ->
        {:ok, {:existing_account, user}}

      {:ok, nil} ->
        case create_client_account(attrs) do
          {:ok, user} -> {:ok, {:account_created, user}}
          {:error, _} = error -> error
        end
    end
  end

  defp create_client_account(attrs) do
    Accounts.create_client_account(
      %{email: attrs[:client_email], profile: %{first_name: attrs[:contact_name]}},
      authorize?: false
    )
  end

  defp normalize(attrs) do
    for {k, v} <- attrs, into: %{} do
      key = if is_atom(k), do: k, else: String.to_existing_atom(k)
      value = if is_binary(v), do: String.trim(v), else: v
      {key, value}
    end
  end

  defp account_type(attrs) do
    case attrs[:account_type] do
      type when type in [:individual, "individual"] -> :individual
      _ -> :business
    end
  end

  defp validate(attrs) do
    cond do
      blank?(attrs[:client_email]) -> {:error, {:required, :client_email}}
      blank?(attrs[:contact_name]) -> {:error, {:required, :contact_name}}
      # Individuals join the pool, so they don't name an organization.
      account_type(attrs) == :business and blank?(attrs[:name]) -> {:error, {:required, :name}}
      true -> :ok
    end
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_), do: false

  defp create_org(attrs, staff) do
    Accounts.create_organization(
      attrs[:name],
      %{owner_user_id: staff.id, account_type: :business},
      actor: staff
    )
  end

  defp invite_client(org, attrs, staff) do
    case client_role(org) do
      nil ->
        {:error, :client_role_missing}

      role ->
        case Fleetms.Membership.invite_member(
               %{email: attrs[:client_email], role_id: role.id},
               org,
               staff
             ) do
          {:ok, :invited, invitation} -> {:ok, {:invited, invitation}}
          {:ok, :added, membership} -> {:ok, {:added, membership}}
          {:error, _} = error -> error
        end
    end
  end

  defp client_role(org) do
    Role
    |> Ash.Query.filter(name == "Client" and is_system == true)
    |> Ash.read_one!(authorize?: false, tenant: org)
  end

  defp create_profile(org, attrs, staff, owner_id \\ nil) do
    Accounts.create_client_profile(
      %{
        organization_id: org.id,
        owner_id: owner_id,
        contact_name: attrs[:contact_name],
        contact_email: attrs[:contact_email],
        contact_phone: attrs[:contact_phone],
        address: attrs[:address],
        reg_number: attrs[:reg_number],
        notes: attrs[:notes]
      },
      actor: staff
    )
  end
end
