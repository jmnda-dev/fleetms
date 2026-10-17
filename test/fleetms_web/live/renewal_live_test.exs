defmodule FleetmsWeb.RenewalLiveTest do
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fleetms.VehicleFixtures

  alias Fleetms.Scope
  alias Fleetms.VehicleManagement

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), org: org, scope: Scope.new(owner, org, true)}
  end

  defp days_from_today(n), do: Date.add(Date.utc_today(), n)

  describe "index" do
    test "lists renewals with status and the create action", %{conn: conn, org: org, scope: scope} do
      type = renewal_type_fixture(scope, "Insurance-#{uniq()}")
      vehicle_renewal_fixture(scope, %{renewal_type_id: type.id, due_date: days_from_today(-1)})

      {:ok, _view, html} = live(conn, ~p"/o/#{org}/renewals")

      assert html =~ "Renewals"
      assert html =~ "New renewal"
      assert html =~ type.name
      assert html =~ "Overdue"
    end

    test "marks a recurring renewal as renewed", %{conn: conn, org: org, scope: scope} do
      renewal =
        vehicle_renewal_fixture(scope, %{
          due_date: ~D[2026-02-01],
          recurrence_interval: 1,
          recurrence_unit: :years
        })

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/renewals")
      render_click(view, "mark-renewed", %{"id" => renewal.id})

      {:ok, reloaded} = VehicleManagement.get_vehicle_renewal(renewal.id, scope: scope)
      assert reloaded.due_date == ~D[2027-02-01]
    end

    test "archives a renewal, then restores it from the archived view", %{
      conn: conn,
      org: org,
      scope: scope
    } do
      renewal = vehicle_renewal_fixture(scope)

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/renewals")
      render_click(view, "archive", %{"id" => renewal.id})

      # archived — hidden everywhere, get can't resolve it
      assert {:error, _} = VehicleManagement.get_vehicle_renewal(renewal.id, scope: scope)

      {:ok, archived, html} = live(conn, ~p"/o/#{org}/renewals?archived=1")
      assert html =~ "Archived renewals"
      assert html =~ "Restore"

      render_click(archived, "restore", %{"id" => renewal.id})

      assert Enum.any?(
               VehicleManagement.list_vehicle_renewals!(%{}, scope: scope).results,
               &(&1.id == renewal.id)
             )
    end
  end

  describe "new" do
    test "renders the form", %{conn: conn, org: org} do
      {:ok, _view, html} = live(conn, ~p"/o/#{org}/renewals/new")

      assert html =~ "New renewal"
      assert html =~ "Due date"
      assert html =~ "Repeats every"
    end

    test "creates a renewal for the chosen vehicle and type", %{
      conn: conn,
      org: org,
      scope: scope
    } do
      vehicle = vehicle_fixture(scope)
      type = renewal_type_fixture(scope, "Roadworthiness-#{uniq()}")

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/renewals/new")

      view
      |> form("#renewal-form", %{
        renewal: %{vehicle_id: vehicle.id, due_date: Date.to_iso8601(days_from_today(90))},
        renewal_type: type.id
      })
      |> render_submit()

      assert {:ok, page} =
               VehicleManagement.list_vehicle_renewals(
                 %{filters: %{"vehicle_id" => vehicle.id}},
                 scope: scope
               )

      assert [renewal] = page.results

      {:ok, loaded} =
        VehicleManagement.get_vehicle_renewal(renewal.id, scope: scope, load: [:renewal_type])

      assert loaded.renewal_type.id == type.id
    end
  end

  describe "edit" do
    test "updates a renewal", %{conn: conn, org: org, scope: scope} do
      renewal = vehicle_renewal_fixture(scope)

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/renewals/#{renewal.id}/edit")

      view
      |> form("#renewal-form", %{renewal: %{comments: "Renewed early"}})
      |> render_submit()

      {:ok, updated} = VehicleManagement.get_vehicle_renewal(renewal.id, scope: scope)
      assert updated.comments == "Renewed early"
    end
  end

  defp uniq, do: System.unique_integer([:positive])
end
