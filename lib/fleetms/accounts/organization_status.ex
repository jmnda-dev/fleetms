defmodule Fleetms.Accounts.OrganizationStatus do
  @moduledoc """
  Lifecycle status of an organization (tenant) on the platform.

    * `:active`    — normal; members can sign in and use the app.
    * `:suspended` — access is blocked for the org's members (e.g. non-payment or
      abuse). Platform staff can still enter to fix or export data.
  """
  use Ash.Type.Enum, values: [:active, :suspended]
end
