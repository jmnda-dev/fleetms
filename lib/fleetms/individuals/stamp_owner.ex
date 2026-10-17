defmodule Fleetms.Individuals.StampOwner do
  @moduledoc """
  Stamps `owner_id` on records created inside the individuals pool, so they belong
  to a specific individual client. Applied to create actions via `Fleetms.Owned`.

  Outside the pool it does nothing (`owner_id` stays nil, as it is for every
  business org). Inside the pool the owner is:

    * the client the acting staff member is working on behalf of, when the scope
      carries one (`Fleetms.Scope` with `on_behalf_of`) — this is how staff create
      a client's vehicles, issues, etc.; otherwise
    * the acting client themselves, when a non-staff member creates their own
      record (e.g. an individual raising an issue).

  Staff creating in the pool without naming a client leave `owner_id` nil (a record
  owned by no client, visible only to staff) — deliberate, not a silent default.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    if Fleetms.Individuals.pool_tenant?(changeset.tenant) do
      case owner_id(changeset, context) do
        nil -> changeset
        owner_id -> Ash.Changeset.force_change_attribute(changeset, :owner_id, owner_id)
      end
    else
      changeset
    end
  end

  defp owner_id(changeset, context) do
    on_behalf_of(changeset) || acting_client_id(context)
  end

  # Shared scope context is merged to the top level of the changeset context.
  defp on_behalf_of(changeset) do
    get_in(changeset.context, [:shared, :individuals_on_behalf_of]) ||
      Map.get(changeset.context, :individuals_on_behalf_of)
  end

  # A non-staff actor in the pool owns what they create; staff must name a client.
  defp acting_client_id(%{actor: %{is_super_admin: true}}), do: nil
  defp acting_client_id(%{actor: %{id: id}}), do: id
  defp acting_client_id(_), do: nil
end
