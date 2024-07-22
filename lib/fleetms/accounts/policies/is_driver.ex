defmodule Fleetms.Accounts.User.Policies.IsDriver do
  @moduledoc """
  Checks if the actor/user has a `viewer` role
  """
  use Ash.Policy.SimpleCheck

  alias Fleetms.Accounts.User

  @impl true
  def describe(_opts), do: "Check if actor has an `driver` role"

  @impl true
  def match?(%User{roles: roles} = _actor, _context, _opts) do
    :driver in roles
  end

  @impl true
  def match?(_actor, _context, _opts), do: false
end
