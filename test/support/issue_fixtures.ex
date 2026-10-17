defmodule Fleetms.IssueFixtures do
  @moduledoc """
  Test fixtures for the issues domain. All take a `Fleetms.Scope` so they run with
  a real actor + tenant, exactly as the web layer would.
  """
  import Fleetms.VehicleFixtures

  alias Fleetms.VehicleIssues

  def issue_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        title: "Issue-#{System.unique_integer([:positive])}",
        vehicle_id: attrs[:vehicle_id] || vehicle_fixture(scope).id
      })

    VehicleIssues.create_issue!(attrs, scope: scope)
  end
end
