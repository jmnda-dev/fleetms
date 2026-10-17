defmodule FleetmsWeb.VehicleLiveTest do
  # Not async (ConnCase default): LiveView tests need shared-mode sandbox so the
  # LiveView process sees the connection's data, and a logged-in owner needs the
  # auth token from a fresh registration — so these create their own org. Being
  # serial, they don't trigger the concurrent-provisioning deadlock.
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fleetms.VehicleFixtures
  import Fleetms.FuelFixtures

  alias Fleetms.Accounts
  alias Fleetms.Scope
  alias Fleetms.VehicleManagement

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), org: org, scope: Scope.new(owner, org, true)}
  end

  describe "status modal" do
    test "opening it shows the status cards, and picking one updates the vehicle", %{
      conn: conn,
      org: org,
      scope: scope
    } do
      vehicle = vehicle_fixture(scope, %{name: "Statused-#{uniq()}", status: :Active})

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/vehicles")

      html =
        view
        |> element("button[phx-click='open_status'][phx-value-id='#{vehicle.id}']")
        |> render_click()

      assert html =~ "Change status"
      # a new status and a "what it implies" description are shown
      assert html =~ "Sold / Disposed"
      assert html =~ "Kept only for history"

      view
      |> element(
        "button[phx-click='set_status'][phx-value-status='Out-of-Service'][phx-value-id='#{vehicle.id}']"
      )
      |> render_click()

      assert VehicleManagement.get_vehicle!(vehicle.id, scope: scope).status == :"Out-of-Service"
    end
  end

  describe "index" do
    test "lists vehicles and shows the add action", %{conn: conn, org: org, scope: scope} do
      vehicle = vehicle_fixture(scope, %{name: "Indexed-#{uniq()}"})

      {:ok, _view, html} = live(conn, ~p"/o/#{org}/vehicles")

      assert html =~ "Vehicles"
      assert html =~ "Add vehicle"
      assert html =~ vehicle.name
    end

    test "search narrows the list", %{conn: conn, org: org, scope: scope} do
      keep = vehicle_fixture(scope, %{name: "Keeper-#{uniq()}"})
      drop = vehicle_fixture(scope, %{name: "Hidden-#{uniq()}"})

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/vehicles")

      html = view |> form("form[phx-change='search']", %{q: "Keeper"}) |> render_change()

      assert html =~ keep.name
      refute html =~ drop.name
    end

    test "deletes a vehicle", %{conn: conn, org: org, scope: scope} do
      vehicle = vehicle_fixture(scope, %{name: "Doomed-#{uniq()}"})

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/vehicles")
      render_click(view, "delete", %{"id" => vehicle.id})

      assert {:error, _} = VehicleManagement.get_vehicle(vehicle.id, scope: scope)
    end
  end

  describe "new" do
    test "renders the accordion form", %{conn: conn, org: org} do
      {:ok, _view, html} = live(conn, ~p"/o/#{org}/vehicles/new")

      assert html =~ "New vehicle"
      assert html =~ "General information"
      assert html =~ "Identification"
      assert html =~ "Purchase &amp; usage"
      assert html =~ "Notes"
      assert html =~ "Engine"
      assert html =~ "Drivetrain"
      assert html =~ "Weights &amp; capacities"
      # The rich-text + datepicker hooks are wired.
      assert html =~ ~s(phx-hook="RichText")
      assert html =~ ~s(phx-hook="DatePicker")
    end

    test "creates a vehicle with engine specs", %{conn: conn, org: org, scope: scope} do
      name = "Specced-#{uniq()}"
      {:ok, view, _html} = live(conn, ~p"/o/#{org}/vehicles/new")

      view
      |> form("#vehicle-form",
        vehicle: %{
          name: name,
          type: "Truck",
          vehicle_spec: %{cylinders: "6", fuel_type: "Diesel"}
        }
      )
      |> render_submit()

      assert [vehicle] =
               VehicleManagement.list_vehicles!(%{search_query: name}, scope: scope).results

      assert {:ok, loaded} =
               VehicleManagement.get_vehicle(vehicle.id, load: [:vehicle_spec], scope: scope)

      assert loaded.vehicle_spec.cylinders == 6
      assert loaded.vehicle_spec.fuel_type == :Diesel
    end

    test "creates a vehicle", %{conn: conn, org: org, scope: scope} do
      name = "Created-#{uniq()}"
      {:ok, view, _html} = live(conn, ~p"/o/#{org}/vehicles/new")

      view
      |> form("#vehicle-form", vehicle: %{name: name, type: "Truck", status: "Active"})
      |> render_submit()

      assert [vehicle] =
               VehicleManagement.list_vehicles!(%{search_query: name}, scope: scope).results

      assert vehicle.name == name
      assert vehicle.type == :Truck
    end
  end

  describe "edit" do
    test "updates a vehicle", %{conn: conn, org: org, scope: scope} do
      vehicle = vehicle_fixture(scope, %{name: "Before-#{uniq()}", type: :Van})
      new_name = "After-#{uniq()}"

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/vehicles/#{vehicle.id}/edit")

      view
      |> form("#vehicle-form", vehicle: %{name: new_name})
      |> render_submit()

      assert {:ok, updated} = VehicleManagement.get_vehicle(vehicle.id, scope: scope)
      assert updated.name == new_name
    end
  end

  describe "show" do
    test "renders the detail tabs and vehicle info", %{conn: conn, org: org, scope: scope} do
      vehicle = vehicle_fixture(scope, %{name: "Shown-#{uniq()}", license_plate: "PLATE-1"})

      {:ok, _view, html} = live(conn, ~p"/o/#{org}/vehicles/#{vehicle.id}")

      assert html =~ vehicle.name
      assert html =~ "Details"
      assert html =~ "Photos"
      assert html =~ "Documents"
      assert html =~ "PLATE-1"
    end

    test "switches tabs", %{conn: conn, org: org, scope: scope} do
      vehicle = vehicle_fixture(scope)

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/vehicles/#{vehicle.id}")
      html = render_click(view, "select-tab", %{"tab" => "documents"})

      assert html =~ "No documents yet."
    end

    test "the meter history tab lists odometer readings from fuel entries", %{
      conn: conn,
      org: org,
      scope: scope
    } do
      vehicle = vehicle_fixture(scope)
      fuel_entry_fixture(scope, %{vehicle_id: vehicle.id, odometer: Decimal.new("12345")})

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/vehicles/#{vehicle.id}")
      html = render_click(view, "select-tab", %{"tab" => "meter"})

      assert html =~ "Meter history"
      assert html =~ "Fuel entry"
    end

    test "shows the warranty section when warranty details are set", %{
      conn: conn,
      org: org,
      scope: scope
    } do
      vehicle =
        vehicle_fixture(scope, %{
          warranty_provider: "Acme Motors",
          warranty_expiration_date: Date.add(Date.utc_today(), 365)
        })

      {:ok, _view, html} = live(conn, ~p"/o/#{org}/vehicles/#{vehicle.id}")

      assert html =~ "Warranty"
      assert html =~ "Acme Motors"
    end

    test "the QR tab renders a scannable code linking to the vehicle", %{
      conn: conn,
      org: org,
      scope: scope
    } do
      vehicle = vehicle_fixture(scope)

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/vehicles/#{vehicle.id}")
      html = render_click(view, "select-tab", %{"tab" => "qr"})

      assert html =~ "<svg"
      assert html =~ "/vehicles/#{vehicle.id}"
      assert html =~ "Print"
    end

    test "the Assignments tab lists who had the vehicle and when", %{
      conn: conn,
      org: org,
      scope: scope
    } do
      vehicle = vehicle_fixture(scope)
      vehicle_assignment_fixture(scope, %{vehicle_id: vehicle.id})

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/vehicles/#{vehicle.id}")
      html = render_click(view, "select-tab", %{"tab" => "assignments"})

      assert html =~ "Driver"
      assert html =~ "In-progress"
      assert html =~ "Ongoing"
    end

    test "the Assignments tab shows an empty state when never assigned", %{
      conn: conn,
      org: org,
      scope: scope
    } do
      vehicle = vehicle_fixture(scope)

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/vehicles/#{vehicle.id}")
      html = render_click(view, "select-tab", %{"tab" => "assignments"})

      assert html =~ "never been assigned"
    end

    test "mileage renders in the org's unit system", %{conn: conn, org: org, scope: scope} do
      vehicle = vehicle_fixture(scope, %{mileage: Decimal.new("12000")})

      {:ok, _view, html} = live(conn, ~p"/o/#{org}/vehicles/#{vehicle.id}")
      assert html =~ "12,000 km"

      # switch the org to imperial → the same value shows in miles
      Accounts.update_organization_settings!(org, %{unit_system: :imperial}, actor: scope.user)

      {:ok, _view, html} = live(conn, ~p"/o/#{org}/vehicles/#{vehicle.id}")
      assert html =~ "7,456.5 mi"
    end

    test "the History tab shows a readable audit timeline", %{conn: conn, org: org, scope: scope} do
      vehicle = vehicle_fixture(scope, %{name: "Histrig"})
      VehicleManagement.update_vehicle!(vehicle, %{name: "Renamed Rig"}, scope: scope)

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/vehicles/#{vehicle.id}")
      html = render_click(view, "select-tab", %{"tab" => "history"})

      assert html =~ "added this vehicle"
      assert html =~ "changed Name from Histrig to Renamed Rig"
    end

    test "posts a comment from the Comments tab", %{conn: conn, org: org, scope: scope} do
      vehicle = vehicle_fixture(scope)

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/vehicles/#{vehicle.id}")
      render_click(view, "select-tab", %{"tab" => "comments"})

      view
      |> form("#comments-#{vehicle.id}-compose", %{body: "Due for tyres"})
      |> render_submit()

      assert render(view) =~ "Due for tyres"

      assert [%{body: "Due for tyres"}] =
               Fleetms.Comments.list_comments!(%{vehicle_id: vehicle.id}, scope: scope)
    end

    test "shows recorded specifications", %{conn: conn, org: org, scope: scope} do
      vehicle = vehicle_fixture(scope)

      VehicleManagement.update_vehicle!(
        vehicle,
        %{vehicle_spec: %{cylinders: 8, drive_type: :"All Wheel Drive(AWD)"}},
        scope: scope
      )

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/vehicles/#{vehicle.id}")
      html = render_click(view, "select-tab", %{"tab" => "specs"})

      assert html =~ "Engine"
      assert html =~ "Drivetrain"
      assert html =~ "All Wheel Drive(AWD)"
    end

    test "shows a placeholder when no specs are recorded", %{conn: conn, org: org, scope: scope} do
      vehicle = vehicle_fixture(scope)

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/vehicles/#{vehicle.id}")
      html = render_click(view, "select-tab", %{"tab" => "specs"})

      assert html =~ "No specifications recorded."
    end

    test "the fuel tab shows economy and entries", %{conn: conn, org: org, scope: scope} do
      vehicle = vehicle_fixture(scope)

      fuel_entry_fixture(scope, %{
        vehicle_id: vehicle.id,
        odometer: Decimal.new("1000"),
        quantity: Decimal.new("40"),
        cost: Money.new(:USD, "60.00")
      })

      fuel_entry_fixture(scope, %{
        vehicle_id: vehicle.id,
        odometer: Decimal.new("1400"),
        quantity: Decimal.new("50"),
        cost: Money.new(:USD, "70.00")
      })

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/vehicles/#{vehicle.id}")
      html = render_click(view, "select-tab", %{"tab" => "fuel"})

      assert html =~ "Fuel economy"
      assert html =~ "Avg economy"
      assert html =~ "Monthly volume"
      # 400 km over the 50 units of the second fill.
      assert html =~ "8.00"
      # Per-currency spend total (60 + 70).
      assert html =~ "130.00"
    end

    test "the fuel tab shows an empty state with no entries", %{
      conn: conn,
      org: org,
      scope: scope
    } do
      vehicle = vehicle_fixture(scope)

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/vehicles/#{vehicle.id}")
      html = render_click(view, "select-tab", %{"tab" => "fuel"})

      assert html =~ "No fuel entries for this vehicle yet."
    end

    test "uploads a photo and sets it as the headline image", %{
      conn: conn,
      org: org,
      scope: scope
    } do
      vehicle = vehicle_fixture(scope)

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/vehicles/#{vehicle.id}")
      render_click(view, "select-tab", %{"tab" => "photos"})

      photo =
        file_input(view, "form[phx-submit='save-photos']", :photos, [
          %{name: "car.png", content: png_bytes(), type: "image/png"}
        ])

      render_upload(photo, "car.png")
      view |> element("form[phx-submit='save-photos']") |> render_submit()

      {:ok, reloaded} = VehicleManagement.get_vehicle(vehicle.id, scope: scope, load: [:photos])
      assert [stored] = reloaded.photos
      assert reloaded.primary_thumbnail_key == stored.thumbnail_key
    end

    test "uploads a document", %{conn: conn, org: org, scope: scope} do
      vehicle = vehicle_fixture(scope)

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/vehicles/#{vehicle.id}")
      render_click(view, "select-tab", %{"tab" => "documents"})

      doc =
        file_input(view, "form[phx-submit='save-documents']", :documents, [
          %{name: "manual.txt", content: "hello fleet", type: "text/plain"}
        ])

      render_upload(doc, "manual.txt")
      view |> element("form[phx-submit='save-documents']") |> render_submit()

      {:ok, reloaded} =
        VehicleManagement.get_vehicle(vehicle.id, scope: scope, load: [:documents])

      assert [%{filename: "manual.txt"}] = reloaded.documents
    end

    test "deletes a photo", %{conn: conn, org: org, scope: scope} do
      vehicle = vehicle_fixture(scope)

      photo =
        VehicleManagement.create_vehicle_photo!(
          %{
            image_key: "vehicles/#{vehicle.id}/photos/og.jpg",
            thumbnail_key: "vehicles/#{vehicle.id}/photos/th.jpg",
            vehicle_id: vehicle.id
          },
          scope: scope
        )

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/vehicles/#{vehicle.id}")
      render_click(view, "select-tab", %{"tab" => "photos"})
      render_click(view, "delete-photo", %{"id" => photo.id})

      {:ok, reloaded} = VehicleManagement.get_vehicle(vehicle.id, scope: scope, load: [:photos])
      assert reloaded.photos == []
    end
  end

  defp png_bytes do
    {:ok, image} = Image.new(24, 24, color: [30, 60, 90])
    {:ok, bytes} = Image.write(image, :memory, suffix: ".png")
    bytes
  end

  defp uniq, do: System.unique_integer([:positive])
end
