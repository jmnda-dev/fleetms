defmodule Fleetms.Accounts.User.Policies.IsAdmin do
  @moduledoc """
  Checks if the actor/user has an `admin` role
  """
  use Ash.Policy.SimpleCheck

  alias Fleetms.Accounts.User

  @impl true
  def describe(_opts), do: "Check if actor has an `admin` role"

  @impl true
  def match?(%User{roles: roles} = _actor, _context, _opts) do
    :admin in roles
  end

  @impl true
  def match?(_actor, _context, _opts), do: false
end
