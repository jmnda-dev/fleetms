defmodule Fleetms.Individuals.ScopeToOwner do
  @moduledoc """
  Read preparation that narrows a query to a single individual client when the
  scope names one (`Fleetms.Scope.on_behalf_of`), inside the individuals pool.

  This is how platform staff manage *one* client's fleet: staff pass each
  resource's `is_super_admin` policy bypass, so the `OwnerCheck` read policy never
  runs for them — but a preparation always does. Outside the pool, or when no
  client is named, it leaves the query untouched.

  Applied to every owner-scoped resource via `Fleetms.Owned`.
  """
  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    with true <- Fleetms.Individuals.pool_tenant?(query.tenant),
         target when not is_nil(target) <- on_behalf_of(query) do
      Ash.Query.filter(query, owner_id == ^target)
    else
      _ -> query
    end
  end

  # Shared scope context is merged to both the top level and under `:shared`.
  defp on_behalf_of(query) do
    get_in(query.context, [:shared, :individuals_on_behalf_of]) ||
      Map.get(query.context, :individuals_on_behalf_of)
  end
end
