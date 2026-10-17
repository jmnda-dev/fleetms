defmodule Fleetms.Scope do
  @moduledoc """
  The per-request "who + which organization" context, assigned to LiveViews as
  `current_scope` and passed to Ash via `scope:`.

  It carries the signed-in `user` (the actor) and the `organization` they are
  currently working in (the tenant). Implementing `Ash.Scope.ToOpts` means a
  single `scope: socket.assigns.current_scope` supplies both the actor and the
  tenant to every code-interface call — and populates `subject.tenant` for the
  permission checks in `Fleetms.Permissions`.

  `owner?` mirrors the membership's owner flag (a per-org super-admin), cached on
  the scope so the UI can gate owner-only affordances without a DB hit.
  """
  alias Fleetms.Accounts.{Organization, User}

  @type t :: %__MODULE__{
          user: User.t() | nil,
          organization: Organization.t() | nil,
          owner?: boolean(),
          staff_access?: boolean(),
          on_behalf_of: Ecto.UUID.t() | nil,
          on_behalf_label: String.t() | nil,
          workspace_name: String.t() | nil
        }

  defstruct [
    :user,
    :organization,
    :on_behalf_of,
    :on_behalf_label,
    :workspace_name,
    owner?: false,
    staff_access?: false
  ]

  @doc """
  The human name to show for the current workspace: for the hidden individuals
  pool that's a person's name (the individual client's own, or the client a staff
  member is managing), so no one sees the internal pool name. Elsewhere it's the
  organization's name.
  """
  @spec workspace_name(t()) :: String.t() | nil
  def workspace_name(%__MODULE__{workspace_name: name, organization: org}) do
    name || (org && org.name)
  end

  def workspace_name(_), do: nil

  @doc """
  Builds a scope for a user working within an organization.

  `staff_access?` marks a session where platform staff (a super-admin) entered an
  organization they are NOT a member of, to act on the client's behalf — used to
  show the impersonation banner and audited on entry.
  """
  @spec new(User.t(), Organization.t(), boolean(), boolean()) :: t()
  def new(%User{} = user, %Organization{} = organization, owner?, staff_access? \\ false) do
    %__MODULE__{
      user: user,
      organization: organization,
      owner?: owner?,
      staff_access?: staff_access?
    }
  end

  @doc "Whether the scoped user owns the scoped organization."
  @spec owner?(t()) :: boolean()
  def owner?(%__MODULE__{owner?: owner?}), do: owner? == true

  @doc """
  Whether the scoped organization is an individual (personal) fleet rather than a
  business/corporate one. Drives UI tailoring only — the data model is identical.
  """
  @spec individual?(t()) :: boolean()
  def individual?(%__MODULE__{organization: %{account_type: :individual}}), do: true
  def individual?(_scope), do: false

  @doc """
  Whether the scoped user holds `permission` in the scoped organization.

  Organization owners are granted every permission (handled by the permission
  cache), so this returns `true` for owners regardless of `permission`.
  """
  @spec has_permission?(t(), atom() | String.t()) :: boolean()
  def has_permission?(%__MODULE__{user: user, organization: org}, permission)
      when not is_nil(user) and not is_nil(org) do
    Fleetms.Permissions.user_has_permission?(user, org, permission)
  end

  def has_permission?(_scope, _permission), do: false

  @doc "Whether the scoped user holds ANY of `permissions` in the scoped organization."
  @spec has_any_permission?(t(), [atom() | String.t()]) :: boolean()
  def has_any_permission?(%__MODULE__{} = scope, permissions) when is_list(permissions) do
    Enum.any?(permissions, &has_permission?(scope, &1))
  end

  @doc """
  Returns a copy of the scope acting on behalf of the individual client `owner_id`.

  Used when platform staff create records for a specific client in the individuals
  pool: the created rows are stamped with the client's `owner_id`, not the staff
  member's. See `Fleetms.Individuals.StampOwner`.
  """
  @spec on_behalf_of(t(), Ecto.UUID.t() | nil, String.t() | nil) :: t()
  def on_behalf_of(%__MODULE__{} = scope, owner_id, label \\ nil) do
    %{scope | on_behalf_of: owner_id, on_behalf_label: label}
  end

  defimpl Ash.Scope.ToOpts do
    def get_actor(%{user: user}), do: {:ok, user}
    # Ash converts the Organization to its schema string via Ash.ToTenant.
    def get_tenant(%{organization: organization}), do: {:ok, organization}
    def get_tracer(_scope), do: :error
    def get_authorize?(_scope), do: :error

    # Surface `on_behalf_of` as shared context so the owner-stamping change can
    # read it. Only set when present, so normal calls carry no extra context.
    def get_context(%{on_behalf_of: nil}), do: :error

    def get_context(%{on_behalf_of: owner_id}),
      do: {:ok, %{shared: %{individuals_on_behalf_of: owner_id}}}
  end
end
