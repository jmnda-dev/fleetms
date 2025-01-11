defmodule Fleetms.Reports.Summary do
  import Ecto.Query

  import Fleetms.Utils,
    only: [
      beginning_of_year: 0,
      end_of_year: 0,
      beginning_of_month: 0,
      end_of_month: 0,
      beginning_of_week: 0,
      end_of_week: 0
    ]

  defstruct vehicle_stats: %{total: 0, active: 0, maintenance: 0, out_of_service: 0},
            issue_stats: %{total: 0, open: 0, closed: 0, resolved: 0},
            inspection_stats: %{
              total_forms: 0,
              total_inspections: 0,
              total_insp_last_seven_days: 0,
              total_insp_passed_last_seven_days: 0,
              total_insp_failed_last_seven_days: 0
            },
            service_reminder_stats: %{
              total_service_groups: 0,
              upcoming: 0,
              due_soon: 0,
              overdue: 0
            },
            work_order_stats: %{
              total: 0,
              open: 0,
              completed: 0
            },
            inventory_stats: %{
              total_parts_value: 0,
              total_in_stock_parts: 0,
              total_low_stock_parts: 0,
              total_out_of_stock_parts: 0,
              total_inventory_locations: 0,
              total_not_tracked_parts: 0
            },
            fuel_stats: %{
              total_costs_current_year: 0,
              total_costs_current_month: 0,
              total_costs_current_week: 0,
              total_costs_today: 0
            },
            maintenance_costs_stats: %{
              total_costs_current_year: 0,
              total_costs_current_month: 0,
              total_costs_current_week: 0
            }

  def get_summary_stats(tenant) do
    vehicle_stats = get_vehicle_stats(tenant)
    issue_stats = get_issue_stats(tenant)
    inspection_stats = get_inspection_stats(tenant)
    service_reminder_stats = get_service_reminder_stats(tenant)
    work_order_stats = get_work_order_stats(tenant)
    inventory_stats = get_inventory_stats(tenant)
    fuel_stats = get_fuel_stats(tenant)
    maintenance_costs_stats = get_maintenance_cost_stats(tenant)

    %__MODULE__{
      vehicle_stats: vehicle_stats,
      issue_stats: issue_stats,
      inspection_stats: inspection_stats,
      service_reminder_stats: service_reminder_stats,
      work_order_stats: work_order_stats,
      inventory_stats: inventory_stats,
      fuel_stats: fuel_stats,
      maintenance_costs_stats: maintenance_costs_stats
    }
  end

  def get_vehicle_stats(tenant) do
    {:ok, ecto_query} =
      Fleetms.VehicleManagement.Vehicle
      |> Ash.Query.new()
      |> Ash.Query.set_tenant(tenant)
      |> Ash.Query.data_layer_query()

    new_query =
      from vehicle in ecto_query,
        select: %{
          total: count(vehicle.id, :distinct),
          active: count(vehicle.id, :distinct) |> filter(vehicle.status == :Active),
          maintenance: count(vehicle.id, :distinct) |> filter(vehicle.status == :Maintenance),
          out_of_service:
            count(vehicle.id, :distinct) |> filter(vehicle.status == :"Out-of-Service")
        },
        distinct: true

    Fleetms.Repo.one(new_query)
  end

  def get_issue_stats(tenant) do
    {:ok, ecto_query} =
      Fleetms.VehicleIssues.Issue
      |> Ash.Query.new()
      |> Ash.Query.set_tenant(tenant)
      |> Ash.Query.data_layer_query()

    new_query =
      from issue in ecto_query,
        select: %{
          total: count(issue.id, :distinct),
          open: count(issue.id, :distinct) |> filter(issue.status == :Open),
          resolved: count(issue.id, :distinct) |> filter(issue.status == :Resolved),
          closed: count(issue.id, :distinct) |> filter(issue.status == :Closed)
        },
        distinct: true

    Fleetms.Repo.one(new_query)
  end

  def get_service_reminder_stats(tenant) do
    {:ok, service_group_query} =
      Fleetms.VehicleMaintenance.ServiceGroup
      |> Ash.Query.new()
      |> Ash.Query.set_tenant(tenant)
      |> Ash.Query.data_layer_query()

    {:ok, service_reminder_query} =
      Fleetms.VehicleMaintenance.ServiceReminder
      |> Ash.Query.new()
      |> Ash.Query.set_tenant(tenant)
      |> Ash.Query.data_layer_query()

    new_query =
      from sg in service_group_query,
        join: sr in ^service_reminder_query,
        on: true,
        select: %{
          total_service_groups: count(sg.id, :distinct),
          upcoming: count(sr.id, :distinct) |> filter(sr.due_status == :Upcoming),
          due_soon: count(sr.id, :distinct) |> filter(sr.due_status == :"Due Soon"),
          overdue: count(sr.id, :distinct) |> filter(sr.due_status == :Overdue)
        },
        distinct: true

    Fleetms.Repo.one(new_query)
  end

  def get_work_order_stats(tenant) do
    {:ok, work_order_query} =
      Fleetms.VehicleMaintenance.WorkOrder
      |> Ash.Query.new()
      |> Ash.Query.set_tenant(tenant)
      |> Ash.Query.data_layer_query()

    new_query =
      from w in work_order_query,
        select: %{
          total: count(w.id, :distinct),
          open: count(w.id, :distinct) |> filter(w.status == :Open),
          completed: count(w.id, :distinct) |> filter(w.status == :Completed)
        },
        distinct: true

    Fleetms.Repo.one(new_query)
  end

  def get_inventory_stats(tenant) do
    {:ok, parts_query} =
      Fleetms.Inventory.Part
      |> Ash.Query.new()
      |> Ash.Query.set_tenant(tenant)
      |> Ash.Query.data_layer_query()

    {:ok, inventory_locations_query} =
      Fleetms.Inventory.InventoryLocation
      |> Ash.Query.new()
      |> Ash.Query.set_tenant(tenant)
      |> Ash.Query.data_layer_query()

    new_query =
      from p in parts_query,
        join: i in ^inventory_locations_query,
        on: true,
        select: %{
          total_parts_value: sum(p.unit_cost) |> filter(p.track_inventory == true),
          total_in_stock_parts:
            count(p.id, :distinct) |> filter(p.stock_quantity_status == :"In Stock"),
          total_low_stock_parts:
            count(p.id, :distinct) |> filter(p.stock_quantity_status == :"Stock Low"),
          total_out_of_stock_parts:
            count(p.id, :distinct) |> filter(p.stock_quantity_status == :"Out of Stock"),
          total_not_tracked_parts:
            count(p.id, :distinct) |> filter(p.stock_quantity_status == :"Not tracked"),
          total_inventory_locations: count(i.id, :distinct)
        },
        distinct: true

    Fleetms.Repo.one(new_query)
  end

  def get_fuel_stats(tenant) do
    {:ok, fuel_histories_query} =
      Fleetms.FuelManagement.FuelHistory
      |> Ash.Query.new()
      |> Ash.Query.set_tenant(tenant)
      |> Ash.Query.data_layer_query()

    new_query =
      from f in fuel_histories_query,
        select: %{
          total_costs_current_year:
            sum(f.refuel_cost)
            |> filter(
              fragment("DATE(?)", f.created_at) >= ^beginning_of_year() and
                fragment("DATE(?)", f.created_at) <= ^end_of_year()
            ),
          total_costs_current_month:
            sum(f.refuel_cost)
            |> filter(
              fragment("DATE(?)", f.created_at) >= ^beginning_of_month() and
                fragment("DATE(?)", f.created_at) <= ^end_of_month()
            ),
          total_costs_current_week:
            sum(f.refuel_cost)
            |> filter(
              fragment("DATE(?)", f.created_at) >= ^beginning_of_week() and
                fragment("DATE(?)", f.created_at) <= ^end_of_week()
            ),
          total_costs_today:
            sum(f.refuel_cost) |> filter(fragment("DATE(?)", f.created_at) == ^Date.utc_today())
        }

    Fleetms.Repo.one(new_query)
  end

  def get_maintenance_cost_stats(tenant) do
    {:ok, work_order_service_task_parts_query} =
      Fleetms.VehicleMaintenance.WorkOrderServiceTaskPart
      |> Ash.Query.new()
      |> Ash.Query.set_tenant(tenant)
      |> Ash.Query.data_layer_query()

    new_query =
      from w in work_order_service_task_parts_query,
        select: %{
          total_costs_current_year:
            sum(w.subtotal)
            |> filter(
              fragment("DATE(?)", w.created_at) >= ^beginning_of_year() and
                fragment("DATE(?)", w.created_at) <= ^end_of_year()
            ),
          total_costs_current_month:
            sum(w.subtotal)
            |> filter(
              fragment("DATE(?)", w.created_at) >= ^beginning_of_month() and
                fragment("DATE(?)", w.created_at) <= ^end_of_month()
            ),
          total_costs_current_week:
            sum(w.subtotal)
            |> filter(
              fragment("DATE(?)", w.created_at) >= ^beginning_of_week() and
                fragment("DATE(?)", w.created_at) <= ^end_of_week()
            )
        }

    Fleetms.Repo.one(new_query)
  end

  def get_inspection_stats(tenant) do
    {:ok, form_query} =
      Fleetms.VehicleInspection.InspectionForm
      |> Ash.Query.new()
      |> Ash.Query.set_tenant(tenant)
      |> Ash.Query.data_layer_query()

    {:ok, submission_query} =
      Fleetms.VehicleInspection.InspectionSubmission
      |> Ash.Query.new()
      |> Ash.Query.set_tenant(tenant)
      |> Ash.Query.data_layer_query()

    {:ok, radio_input_values_query} =
      Fleetms.VehicleInspection.RadioInputValue
      |> Ash.Query.new()
      |> Ash.Query.set_tenant(tenant)
      |> Ash.Query.data_layer_query()

    {:ok, dropdown_input_values_query} =
      Fleetms.VehicleInspection.DropdownInputValue
      |> Ash.Query.new()
      |> Ash.Query.set_tenant(tenant)
      |> Ash.Query.data_layer_query()

    {:ok, number_input_values_query} =
      Fleetms.VehicleInspection.NumberInputValue
      |> Ash.Query.new()
      |> Ash.Query.set_tenant(tenant)
      |> Ash.Query.data_layer_query()

    now = Date.utc_today()
    last_seven_days = Timex.shift(now, days: -7)

    pass_value = "Pass"
    fail_value = "Fail"

    new_query =
      from(f in form_query,
        join: i in ^submission_query,
        as: :inspection_submission,
        on: true,
        select: %{
          total_forms: count(f.id, :distinct),
          total_inspections: count(i.id, :distinct),
          total_insp_last_seven_days:
            count(i.id, :distinct)
            |> filter(
              i.created_at >= ^last_seven_days and fragment("DATE(?)", i.created_at) == ^now
            ),
          total_insp_passed_last_seven_days:
            filter(
              count(i.id),
              i.created_at >= ^last_seven_days and fragment("DATE(?)", i.created_at) <= ^now and
                ^pass_value ==
                  all(
                    from(p in radio_input_values_query,
                      where: parent_as(:inspection_submission).id == p.inspection_submission_id,
                      select: p.status
                    )
                  ) and
                ^pass_value ==
                  all(
                    from(d in dropdown_input_values_query,
                      where: parent_as(:inspection_submission).id == d.inspection_submission_id,
                      select: d.status
                    )
                  ) and
                ^pass_value ==
                  all(
                    from(n in number_input_values_query,
                      where: parent_as(:inspection_submission).id == n.inspection_submission_id,
                      select: n.status
                    )
                  )
            ),
          total_insp_failed_last_seven_days:
            filter(
              count(i.id),
              i.created_at >= ^last_seven_days and fragment("DATE(?)", i.created_at) <= ^now and
                (^fail_value ==
                   any(
                     from(p in radio_input_values_query,
                       where: parent_as(:inspection_submission).id == p.inspection_submission_id,
                       select: p.status
                     )
                   ) or
                   ^fail_value ==
                     any(
                       from(d in dropdown_input_values_query,
                         where:
                           parent_as(:inspection_submission).id == d.inspection_submission_id,
                         select: d.status
                       )
                     ) or
                   ^fail_value ==
                     any(
                       from(n in number_input_values_query,
                         where:
                           parent_as(:inspection_submission).id == n.inspection_submission_id,
                         select: n.status
                       )
                     ))
            )
        },
        distinct: true
      )

    Fleetms.Repo.one(new_query)
  end
end
