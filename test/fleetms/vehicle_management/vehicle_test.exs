defmodule Fleetms.VehicleManagement.VehicleTest do
  use Fleetms.DataCase, async: true

  import Fleetms.VehicleFixtures

  alias Fleetms.Scope
  alias Fleetms.VehicleManagement

  setup :shared_org

  describe "picker filters" do
    test "list_assignable is Active-only; list_selectable is everything but Sold", %{scope: scope} do
      active = vehicle_fixture(scope, %{status: :Active})
      shop = vehicle_fixture(scope, %{status: :Maintenance})
      oos = vehicle_fixture(scope, %{status: :"Out-of-Service"})
      sold = vehicle_fixture(scope, %{status: :Sold})

      assignable = Enum.map(VehicleManagement.list_assignable_vehicles!(scope: scope), & &1.id)
      assert active.id in assignable
      refute shop.id in assignable
      refute oos.id in assignable
      refute sold.id in assignable

      selectable = Enum.map(VehicleManagement.list_selectable_vehicles!(scope: scope), & &1.id)
      assert active.id in selectable
      assert shop.id in selectable
      assert oos.id in selectable
      refute sold.id in selectable
    end
  end

  describe "create/read" do
    test "creates a vehicle and reads it back by id", %{scope: scope} do
      name = "Truck-#{System.unique_integer([:positive])}"

      assert {:ok, vehicle} =
               VehicleManagement.create_vehicle(%{name: name, type: :Truck, status: :Active},
                 scope: scope
               )

      assert vehicle.name == name
      assert vehicle.type == :Truck
      assert vehicle.mileage == Decimal.new(0)

      assert {:ok, fetched} = VehicleManagement.get_vehicle(vehicle.id, scope: scope)
      assert fetched.id == vehicle.id
    end

    test "requires a type", %{scope: scope} do
      assert {:error, %Ash.Error.Invalid{}} =
               VehicleManagement.create_vehicle(%{name: "No Type"}, scope: scope)
    end

    test "full_name calculation collapses to the name when make/model are unset",
         %{scope: scope} do
      name = "Lonely-#{System.unique_integer([:positive])}"
      vehicle = vehicle_fixture(scope, %{name: name})

      assert {:ok, loaded} =
               VehicleManagement.get_vehicle(vehicle.id, load: [:full_name], scope: scope)

      assert loaded.full_name == name
    end

    test "full_name calculation includes make and model when present", %{scope: scope} do
      make = vehicle_make_fixture(scope)
      model = vehicle_model_fixture(scope, make)

      vehicle = vehicle_fixture(scope, %{name: "T-1", vehicle_model_id: model.id})

      assert {:ok, loaded} =
               VehicleManagement.get_vehicle(vehicle.id, load: [:full_name], scope: scope)

      assert loaded.full_name == "#{make.name} #{model.name} - T-1"
    end
  end

  describe "makes and models (find-or-create)" do
    test "upserting a make twice returns the same record", %{scope: scope} do
      name = "Volvo-#{System.unique_integer([:positive])}"
      a = vehicle_make_fixture(scope, name)
      b = VehicleManagement.upsert_vehicle_make!(%{name: name}, scope: scope)
      assert a.id == b.id
    end

    test "models are scoped to their make and listable by make", %{scope: scope} do
      toyota = vehicle_make_fixture(scope)
      honda = vehicle_make_fixture(scope)

      hilux = vehicle_model_fixture(scope, toyota)
      _civic = vehicle_model_fixture(scope, honda)

      assert {:ok, models} =
               VehicleManagement.list_vehicle_models_by_make(toyota.id, scope: scope)

      assert Enum.map(models, & &1.id) == [hilux.id]
    end

    test "the same model name can exist under different makes", %{scope: scope} do
      a = vehicle_make_fixture(scope)
      b = vehicle_make_fixture(scope)
      model_name = "Ranger-#{System.unique_integer([:positive])}"

      m1 = vehicle_model_fixture(scope, a, model_name)
      m2 = vehicle_model_fixture(scope, b, model_name)
      refute m1.id == m2.id
    end
  end

  describe "update" do
    test "rejects lowering mileage below the current reading", %{scope: scope} do
      vehicle = vehicle_fixture(scope, %{mileage: Decimal.new(5000)})

      assert {:error, %Ash.Error.Invalid{}} =
               VehicleManagement.update_vehicle(vehicle, %{mileage: Decimal.new(4000)},
                 scope: scope
               )

      assert {:ok, _} =
               VehicleManagement.update_vehicle(vehicle, %{mileage: Decimal.new(6000)},
                 scope: scope
               )
    end
  end

  describe "list: search, filter, sort, paginate" do
    setup %{scope: scope} do
      suffix = System.unique_integer([:positive])
      # A distinctive plate that won't trigram-match the vehicle names (the low
      # search threshold otherwise matches a shared numeric suffix).
      plate = "QXKZTP"
      toyota = vehicle_make_fixture(scope)
      hilux = vehicle_model_fixture(scope, toyota, "Hilux-#{suffix}")

      v1 =
        vehicle_fixture(scope, %{
          name: "Alpha-#{suffix}",
          type: :Truck,
          status: :Active,
          year: 2018,
          license_plate: plate,
          vehicle_model_id: hilux.id
        })

      v2 =
        vehicle_fixture(scope, %{
          name: "Bravo-#{suffix}",
          type: :Van,
          status: :Maintenance,
          year: 2022
        })

      %{toyota: toyota, hilux: hilux, v1: v1, v2: v2, plate: plate}
    end

    test "returns a countable page", %{scope: scope} do
      assert %Ash.Page.Offset{results: results, count: count} =
               VehicleManagement.list_vehicles!(%{}, page: [limit: 10, count: true], scope: scope)

      assert count == 2
      assert length(results) == 2
    end

    test "trigram search matches partial names", %{scope: scope, v1: v1} do
      page = VehicleManagement.list_vehicles!(%{search_query: "Alph"}, scope: scope)
      assert Enum.map(page.results, & &1.id) == [v1.id]
    end

    test "trigram search matches make/model and plate", %{scope: scope, v1: v1, plate: plate} do
      assert [%{id: id}] =
               VehicleManagement.list_vehicles!(%{search_query: "Hilux"}, scope: scope).results

      assert id == v1.id

      assert [%{id: ^id}] =
               VehicleManagement.list_vehicles!(%{search_query: plate}, scope: scope).results
    end

    test "filters by status", %{scope: scope, v2: v2} do
      page =
        VehicleManagement.list_vehicles!(%{filters: %{"statuses" => ["Maintenance"]}},
          scope: scope
        )

      assert Enum.map(page.results, & &1.id) == [v2.id]
    end

    test "filters by make", %{scope: scope, toyota: toyota, v1: v1} do
      page = VehicleManagement.list_vehicles!(%{filters: %{"make_id" => toyota.id}}, scope: scope)
      assert Enum.map(page.results, & &1.id) == [v1.id]
    end

    test "filters by year range", %{scope: scope, v2: v2} do
      page = VehicleManagement.list_vehicles!(%{filters: %{"year_min" => "2020"}}, scope: scope)
      assert Enum.map(page.results, & &1.id) == [v2.id]
    end

    test "sorts by name descending", %{scope: scope, v1: v1, v2: v2} do
      page =
        VehicleManagement.list_vehicles!(%{sort_by: :name, sort_order: :desc}, scope: scope)

      assert Enum.map(page.results, & &1.id) == [v2.id, v1.id]
    end

    test "sort holds when the make/model relationship is loaded for display", %{
      scope: scope,
      v1: v1,
      v2: v2
    } do
      page =
        VehicleManagement.list_vehicles!(%{sort_by: :name, sort_order: :desc},
          load: [vehicle_model: [:vehicle_make]],
          scope: scope
        )

      assert Enum.map(page.results, & &1.id) == [v2.id, v1.id]
    end
  end

  describe "destroy" do
    test "deleting a vehicle cascades its photos and documents", %{scope: scope} do
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

      document =
        VehicleManagement.create_vehicle_document!(
          %{
            filename: "Insurance.pdf",
            storage_key: "vehicles/#{vehicle.id}/documents/ins.pdf",
            vehicle_id: vehicle.id
          },
          scope: scope
        )

      assert :ok = VehicleManagement.delete_vehicle(vehicle, scope: scope)

      assert {:error, _} = VehicleManagement.get_vehicle(vehicle.id, scope: scope)
      assert {:ok, []} = VehicleManagement.list_vehicle_documents(vehicle.id, scope: scope)
      # The photo row is gone too (cascade).
      assert [] =
               Ash.read!(Fleetms.VehicleManagement.VehiclePhoto,
                 tenant: scope.organization,
                 authorize?: false
               )

      refute photo.id == nil
      refute document.id == nil
    end
  end

  describe "uploads (generic actions)" do
    test "upload_vehicle_photo processes and stores an image", %{scope: scope} do
      vehicle = vehicle_fixture(scope)
      source = Path.join(System.tmp_dir!(), "src-#{System.unique_integer([:positive])}.png")
      Image.new!(30, 30, color: [10, 20, 30]) |> Image.write!(source)

      assert {:ok, photo} =
               VehicleManagement.upload_vehicle_photo(
                 %{vehicle_id: vehicle.id, source_path: source},
                 scope: scope
               )

      assert photo.image_key
      assert photo.thumbnail_key
      assert Fleetms.Storage.exists?(photo.image_key)
      assert Fleetms.Storage.exists?(photo.thumbnail_key)

      File.rm(source)
    end

    test "upload_vehicle_document stores the file and records its metadata", %{scope: scope} do
      vehicle = vehicle_fixture(scope)
      source = Path.join(System.tmp_dir!(), "doc-#{System.unique_integer([:positive])}.txt")
      File.write!(source, "hello fleet")

      assert {:ok, document} =
               VehicleManagement.upload_vehicle_document(
                 %{
                   vehicle_id: vehicle.id,
                   source_path: source,
                   filename: "report.txt",
                   content_type: "text/plain",
                   byte_size: 11
                 },
                 scope: scope
               )

      assert document.filename == "report.txt"
      assert document.storage_key
      assert {:ok, "hello fleet"} = Fleetms.Storage.get(document.storage_key)

      File.rm(source)
    end

    test "upload_vehicle_photo requires a source_path", %{scope: scope} do
      vehicle = vehicle_fixture(scope)

      assert {:error, %Ash.Error.Invalid{}} =
               VehicleManagement.upload_vehicle_photo(%{vehicle_id: vehicle.id}, scope: scope)
    end
  end

  describe "specifications" do
    test "creates a vehicle with a managed spec", %{scope: scope} do
      assert {:ok, vehicle} =
               VehicleManagement.create_vehicle(
                 %{
                   name: "Spec-#{System.unique_integer([:positive])}",
                   type: :Truck,
                   vehicle_spec: %{
                     cylinders: 6,
                     fuel_type: :Diesel,
                     drive_type: :"Four Wheel Drive(4WD)",
                     power: Decimal.new("120.5")
                   }
                 },
                 scope: scope
               )

      assert {:ok, loaded} =
               VehicleManagement.get_vehicle(vehicle.id, load: [:vehicle_spec], scope: scope)

      assert loaded.vehicle_spec.cylinders == 6
      assert loaded.vehicle_spec.fuel_type == :Diesel
      assert loaded.vehicle_spec.drive_type == :"Four Wheel Drive(4WD)"
    end

    test "adds and updates the spec on an existing vehicle", %{scope: scope} do
      vehicle = vehicle_fixture(scope)

      assert {:ok, _} =
               VehicleManagement.update_vehicle(
                 vehicle,
                 %{vehicle_spec: %{cylinders: 4, transmission_type: :Automatic}},
                 scope: scope
               )

      assert {:ok, loaded} =
               VehicleManagement.get_vehicle(vehicle.id, load: [:vehicle_spec], scope: scope)

      assert loaded.vehicle_spec.cylinders == 4
      assert loaded.vehicle_spec.transmission_type == :Automatic
    end

    test "rejects an out-of-range enum value", %{scope: scope} do
      assert {:error, %Ash.Error.Invalid{}} =
               VehicleManagement.create_vehicle(
                 %{
                   name: "Bad-#{System.unique_integer([:positive])}",
                   type: :Truck,
                   vehicle_spec: %{fuel_type: :Plutonium}
                 },
                 scope: scope
               )
    end
  end

  describe "authorization" do
    test "a non-member cannot create vehicles in the org", %{org: org} do
      outsider = user_fixture()

      assert {:error, %Ash.Error.Forbidden{}} =
               VehicleManagement.create_vehicle(%{name: "X", type: :Truck},
                 scope: Scope.new(outsider, org, false)
               )
    end

    test "a non-member sees no vehicles (read is filtered, not leaked)", %{scope: scope, org: org} do
      vehicle_fixture(scope)
      outsider = user_fixture()

      assert {:ok, %{results: []}} =
               VehicleManagement.list_vehicles(%{}, scope: Scope.new(outsider, org, false))
    end
  end
end
