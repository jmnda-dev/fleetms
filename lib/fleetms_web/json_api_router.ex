defmodule FleetmsWeb.JsonApiRouter do
  @moduledoc """
  The public JSON:API surface, derived from the Ash domains that declare a
  `json_api` block. Mounted at `/api/v1` behind bearer auth + the tenant header
  (see the `:json_api` pipeline). Serves an OpenAPI 3 spec at `/api/v1/open_api`.
  """
  use AshJsonApi.Router,
    domains: [
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

  # The OpenAPI spec + Swagger UI are served publicly (schema only, no data) by
  # dedicated routes in FleetmsWeb.Router, so they aren't gated behind the API's
  # bearer-token + tenant pipeline. So no `open_api:` option here.
end
