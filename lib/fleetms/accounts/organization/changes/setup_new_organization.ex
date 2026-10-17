defmodule Fleetms.Accounts.Organization.Changes.SetupNewOrganization do
  @moduledoc """
  On organization creation:

    * relates the creating user as the organization owner (`UserOrganization` with
      `owner?: true`), in the same transaction; and
    * seeds the default system roles into the organization's tenant schema after the
      transaction commits (the tenant schema is guaranteed to exist by then).
  """
  use Ash.Resource.Change

  alias Fleetms.Accounts.UserOrganization

  @impl true
  def change(changeset, _opts, _context) do
    owner_user_id = Ash.Changeset.get_argument(changeset, :owner_user_id)

    changeset
    |> Ash.Changeset.after_action(fn _changeset, org ->
      UserOrganization
      |> Ash.Changeset.for_create(
        :create,
        %{user_id: owner_user_id, organization_id: org.id, owner?: true},
        authorize?: false
      )
      |> Ash.create!()

      {:ok, org}
    end)
    |> Ash.Changeset.after_transaction(fn
      _changeset, {:ok, org} ->
        Fleetms.Permissions.Seeder.seed_for_org!(org)
        {:ok, org}

      _changeset, other ->
        other
    end)
  end
end
