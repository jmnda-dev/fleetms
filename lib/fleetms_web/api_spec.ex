defmodule FleetmsWeb.ApiSpec do
  @moduledoc """
  Builds the OpenAPI 3 spec for the public JSON:API, derived by AshJsonApi from
  the same domains the router exposes. Served publicly (schema only, no data) at
  `/api/v1/open_api`, with a Swagger UI at `/api/v1/docs`.
  """
  @behaviour OpenApiSpex.OpenApi

  @domains [
    Fleetms.VehicleManagement,
    Fleetms.VehicleIssues,
    Fleetms.Maintenance,
    Fleetms.FuelManagement,
    Fleetms.Expenses,
    Fleetms.Drivers,
    Fleetms.Contacts,
    Fleetms.Inventory,
    Fleetms.Tagging,
    Fleetms.Accounts,
    Fleetms.Notifications,
    Fleetms.Inspections
  ]

  @impl OpenApiSpex.OpenApi
  def spec do
    AshJsonApi.OpenApi.spec(domains: @domains, phoenix_endpoint: FleetmsWeb.Endpoint)
  end
end
