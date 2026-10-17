defmodule Fleetms.Individuals.OwnerCheck do
  @moduledoc """
  Policy filter that isolates individual clients within the shared pool schema.

  Applied (via `Fleetms.Owned`) to the read policies of every owner-scoped
  resource. It restricts rows to the acting client's own (`owner_id == actor.id`)
  **only** inside the individuals pool. Everywhere else it authorizes all rows, so
  ordinary organizations — where `owner_id` is always nil — are untouched:

    * not the pool tenant → no restriction (business orgs, and any non-pool schema)
    * platform staff (super-admin) → no restriction (a pool-wide view)
    * otherwise (an individual client in the pool) → `owner_id == actor.id`

  Staff managing *one* client's fleet is handled separately by
  `Fleetms.Individuals.ScopeToOwner` (a preparation), because staff pass the
  resource's `is_super_admin` bypass and so never reach this policy.
  """
  use Ash.Policy.FilterCheck

  require Ash.Expr

  @impl true
  def describe(_opts) do
    "restricted to the individual client's own records within the individuals pool"
  end

  @impl true
  def filter(actor, authorizer, _opts) do
    cond do
      not Fleetms.Individuals.pool_tenant?(tenant(authorizer)) -> true
      super_admin?(actor) -> true
      is_nil(actor) -> false
      true -> Ash.Expr.expr(owner_id == ^actor(:id))
    end
  end

  defp tenant(%{subject: %{tenant: tenant}}), do: tenant
  defp tenant(_), do: nil

  defp super_admin?(%{is_super_admin: true}), do: true
  defp super_admin?(_), do: false
end
