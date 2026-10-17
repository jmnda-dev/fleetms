defmodule FleetmsWeb.ReportController do
  @moduledoc """
  CSV downloads for the reports. Each action resolves the report from
  `Fleetms.Reports` (with the `current_scope` set by `RequireOrganization`) and streams
  it as an attachment. Amounts are plain decimals — no grouping or currency symbol — so
  the file drops straight into a spreadsheet; the currency is named in a trailing column.
  """
  use FleetmsWeb, :controller

  alias Fleetms.Format
  alias Fleetms.Reports

  NimbleCSV.define(FleetmsWeb.CSV, [])

  def maintenance(conn, params) do
    scope = conn.assigns.current_scope
    report = Reports.maintenance_report(scope, params)
    org = scope.organization

    header = [
      "Work order",
      "Vehicle",
      "Issued",
      "Status",
      "Tasks",
      "Parts",
      "Labour",
      "Total",
      "Currency"
    ]

    rows =
      Enum.map(report.rows, fn r ->
        [
          "##{r.number}",
          r.vehicle || "",
          Format.date(r.issued_at, org),
          humanize(r.status),
          r.task_count,
          decimal(r.parts),
          decimal(r.labour),
          decimal(r.total),
          report.currency
        ]
      end)

    send_csv(conn, [header | rows], "maintenance-report.csv")
  end

  def cost_of_ownership(conn, params) do
    scope = conn.assigns.current_scope
    report = Reports.cost_of_ownership_report(scope, params)
    org = scope.organization
    unit = Format.distance_unit(org)

    header = [
      "Vehicle",
      "Maintenance",
      "Fuel",
      "Expenses",
      "Total",
      "Distance (#{unit})",
      "Cost per #{unit}",
      "Currency"
    ]

    rows =
      Enum.map(report.rows, fn r ->
        distance = Format.distance_value(r.distance, org)

        [
          r.vehicle || "",
          decimal(r.maintenance),
          decimal(r.fuel),
          decimal(r.expenses),
          decimal(r.total),
          (distance && decimal(distance)) || "",
          cost_per(r.total, distance),
          report.currency
        ]
      end)

    send_csv(conn, [header | rows], "cost-of-ownership.csv")
  end

  def fuel(conn, params) do
    scope = conn.assigns.current_scope
    report = Reports.fuel_report(scope, params)
    org = scope.organization
    vunit = Format.volume_unit(org)

    header = ["Date", "Vehicle", "Quantity (#{vunit})", "Cost", "Currency", "Odometer", "Economy"]

    rows =
      Enum.map(report.rows, fn r ->
        [
          Format.date(r.date, org),
          r.vehicle || "",
          decimal(Format.volume_value(r.quantity, org)),
          (r.cost && decimal(r.cost.amount)) || "",
          (r.cost && to_string(r.cost.currency)) || "",
          (r.odometer && decimal(Format.distance_value(r.odometer, org))) || "",
          economy(r.economy, org)
        ]
      end)

    send_csv(conn, [header | rows], "fuel-report.csv")
  end

  def roster(conn, params) do
    scope = conn.assigns.current_scope
    report = Reports.vehicle_roster(scope, params)
    org = scope.organization
    dunit = Format.distance_unit(org)

    header = [
      "Name",
      "Make",
      "Model",
      "Status",
      "Plate",
      "VIN",
      "Year",
      "Mileage (#{dunit})",
      "Purchased"
    ]

    rows =
      Enum.map(report.rows, fn r ->
        [
          r.name,
          r.make || "",
          r.model || "",
          (r.status && to_string(r.status)) || "",
          r.license_plate || "",
          r.vin || "",
          r.year || "",
          (r.mileage && decimal(Format.distance_value(r.mileage, org))) || "",
          (r.purchase_date && Format.date(r.purchase_date, org)) || ""
        ]
      end)

    send_csv(conn, [header | rows], "vehicle-roster.csv")
  end

  defp economy(nil, _org), do: ""
  defp economy(%{distance_km: d, fuel_l: f}, org), do: Format.fuel_economy(d, f, org)

  defp cost_per(total, %Decimal{} = distance) do
    if Decimal.compare(distance, Decimal.new(0)) == :gt,
      do: decimal(Decimal.div(total, distance)),
      else: ""
  end

  defp cost_per(_total, _distance), do: ""

  defp send_csv(conn, rows, filename) do
    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, FleetmsWeb.CSV.dump_to_iodata(rows))
  end

  # Plain, ungrouped decimal string rounded to 2 places — for spreadsheet math.
  defp decimal(%Decimal{} = value), do: value |> Decimal.round(2) |> Decimal.to_string(:normal)

  defp humanize(status),
    do: status |> to_string() |> String.replace("_", " ") |> String.capitalize()
end
