defmodule Fleetms.Owned do
  @moduledoc """
  A resource fragment that makes a resource *owner-scoped* for the individuals
  pool. Add it to any user-facing tenant resource:

      use Ash.Resource,
        # ...,
        fragments: [Fleetms.Owned]

  It contributes, in one place so no resource can get the pieces out of step:

    * an `owner_id` attribute (nullable) and an `owner` relationship to the
      `User` who owns the record — a cross-schema reference to `public.users`,
      like the other tenant→user links;
    * a create-time `change` (`Fleetms.Individuals.StampOwner`) that stamps
      `owner_id` inside the individuals pool;
    * a read `policy` (`Fleetms.Individuals.OwnerCheck`) that filters rows to the
      owning client inside the pool.

  Outside the pool `owner_id` stays nil and the policy authorizes every row, so
  ordinary organizations are unaffected. The resource must use
  `Ash.Policy.Authorizer` (all of ours do) for the policy to take effect; the
  owner read-policy composes with the resource's existing permission policies
  (all must pass), and the `is_super_admin` bypass still lets staff see everything.
  """
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  attributes do
    attribute :owner_id, :uuid do
      allow_nil? true
      public? false

      description "The individual client who owns this record (individuals pool only; nil elsewhere)."
    end
  end

  relationships do
    belongs_to :owner, Fleetms.Accounts.User do
      source_attribute :owner_id
      define_attribute? false
    end
  end

  changes do
    change Fleetms.Individuals.StampOwner, on: [:create]
  end

  # Narrows reads to one client when staff are managing a single individual (they
  # bypass the read policy below, so this preparation carries that case).
  preparations do
    prepare Fleetms.Individuals.ScopeToOwner
  end

  policies do
    policy action_type(:read) do
      authorize_if Fleetms.Individuals.OwnerCheck
    end
  end
end
