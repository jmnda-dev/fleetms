defmodule Fleetms.Accounts.User.Policies.IsFleetManager do
  @moduledoc """
  Checks if the actor/user has a `fleet_manager` role
  """
  use Ash.Policy.SimpleCheck

  alias Fleetms.Accounts.User

  @impl true
  def describe(_opts), do: "Check if actor has an `fleet_manager` role"

  @impl true
  def match?(%User{roles: roles} = _actor, _context, _opts) do
    :fleet_manager in roles
  end

  @impl true
  def match?(_actor, _context, _opts), do: false
end
