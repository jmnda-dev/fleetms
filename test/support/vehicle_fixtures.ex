defmodule Fleetms.VehicleFixtures do
  @moduledoc """
  Test fixtures for the vehicle domain. All take a `Fleetms.Scope` so they run
  with a real actor + tenant, exactly as the web layer would.
  """
  alias Fleetms.VehicleManagement

  def vehicle_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "VH-#{System.unique_integer([:positive])}",
        type: :Truck
      })

    VehicleManagement.create_vehicle!(attrs, scope: scope)
  end

  def vehicle_make_fixture(scope, name \\ nil) do
    name = name || "Make #{System.unique_integer([:positive])}"
    VehicleManagement.upsert_vehicle_make!(%{name: name}, scope: scope)
  end

  def vehicle_model_fixture(scope, make, name \\ nil) do
    name = name || "Model #{System.unique_integer([:positive])}"
    VehicleManagement.upsert_vehicle_model!(%{name: name, vehicle_make_id: make.id}, scope: scope)
  end

  def vehicle_group_fixture(scope, name \\ nil) do
    name = name || "Group #{System.unique_integer([:positive])}"
    VehicleManagement.create_vehicle_group!(%{name: name}, scope: scope)
  end

  def vehicle_assignment_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        vehicle_id: attrs[:vehicle_id] || vehicle_fixture(scope).id,
        assignee_id: attrs[:assignee_id] || scope.user.id,
        start_datetime: attrs[:start_datetime] || DateTime.truncate(DateTime.utc_now(), :second)
      })

    VehicleManagement.create_vehicle_assignment!(attrs, scope: scope)
  end

  def driver_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        first_name: "Driver",
        last_name: "#{System.unique_integer([:positive])}"
      })

    Fleetms.Drivers.create_driver!(attrs, scope: scope)
  end

  def renewal_type_fixture(scope, name \\ nil) do
    name = name || "Type #{System.unique_integer([:positive])}"
    VehicleManagement.upsert_renewal_type!(%{name: name}, scope: scope)
  end

  def vehicle_renewal_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        vehicle_id: attrs[:vehicle_id] || vehicle_fixture(scope).id,
        renewal_type_id: attrs[:renewal_type_id] || renewal_type_fixture(scope).id,
        due_date: attrs[:due_date] || Date.add(Date.utc_today(), 365)
      })

    VehicleManagement.create_vehicle_renewal!(attrs, scope: scope)
  end
end
