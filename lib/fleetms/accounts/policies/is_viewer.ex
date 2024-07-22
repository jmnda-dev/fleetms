defmodule Fleetms.Accounts.User.Policies.IsViewer do
  @moduledoc """
  Checks if the actor/user has a `viewer` role
  """
  use Ash.Policy.SimpleCheck

  alias Fleetms.Accounts.User

  @impl true
  def describe(_opts), do: "Check if actor has an `viewer` role"

  @impl true
  def match?(%User{roles: roles} = _actor, _context, _opts) do
    :viewer in roles
  end

  @impl true
  def match?(_actor, _context, _opts), do: false
end
