# Seeds a rich, demo-ready dataset:
#
#   * A corporate fleet ("Kabwe Haulage Ltd") with owner + members, a fleet of
#     trucks/pickups/vans, and data across every module (issues, work orders,
#     fuel, parts, reminders, renewals, inspections, tags, assignments, drivers,
#     contacts, expenses).
#   * An individual client ("Chanda", in the shared individuals pool) with vehicles
#     and lighter activity.
#
# Money is ZMW and units are metric (the org defaults), with Zambian names,
# plates and towns, so the deployed app looks alive rather than empty.
#
# Placeholder vehicle images and dummy PDF documents live in
# priv/repo/seed_assets/ (generated, copyright-safe) and are copied into storage.
#
# Run with:  mix run priv/repo/seeds.exs   (also runs via `mix ecto.setup`)
# Idempotent-ish: it skips if any organization already exists.

alias Fleetms.Accounts
alias Fleetms.Inspections
alias Fleetms.Contacts
alias Fleetms.Drivers
alias Fleetms.Expenses
alias Fleetms.Inventory
alias Fleetms.FuelManagement
alias Fleetms.Maintenance
alias Fleetms.Scope
alias Fleetms.Tagging
alias Fleetms.VehicleIssues
alias Fleetms.VehicleManagement

defmodule Seeds do
  @moduledoc false
  @assets_dir Path.join(__DIR__, "seed_assets")

  # --- time helpers (relative to "today" at run time) ---
  def today, do: Date.utc_today()
  def days_ago(n), do: Date.add(today(), -n)
  def days_ahead(n), do: Date.add(today(), n)
  def now, do: DateTime.truncate(DateTime.utc_now(), :second)
  def ago(days), do: DateTime.add(now(), -days * 86_400, :second)

  def zmw(amount), do: Money.new(:ZMW, amount)
  def dec(n), do: Decimal.new(n)

  # --- accounts ---
  def owner(email, first, last, org_name, account_type \\ :business) do
    user =
      Accounts.User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: email,
        password: "password1234",
        password_confirmation: "password1234"
      })
      |> Ash.create!(authorize?: false)
      |> then(&Ash.Seed.update!(&1, %{confirmed_at: DateTime.utc_now()}))

    Accounts.create_user_profile!(
      %{user_id: user.id, first_name: first, last_name: last},
      authorize?: false
    )

    org =
      Accounts.create_organization!(
        org_name,
        %{owner_user_id: user.id, account_type: account_type},
        actor: user
      )

    {user, org, Scope.new(user, org, true)}
  end

  # Platform staff (is_super_admin) — no org of their own; used to reach /admin.
  def platform_admin(email, first, last) do
    user =
      Accounts.User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: email,
        password: "password1234",
        password_confirmation: "password1234"
      })
      |> Ash.create!(authorize?: false)
      |> then(&Ash.Seed.update!(&1, %{confirmed_at: DateTime.utc_now(), is_super_admin: true}))

    Accounts.create_user_profile!(
      %{user_id: user.id, first_name: first, last_name: last},
      authorize?: false
    )

    user
  end

  # Provisions an individual client into the shared pool (as staff would), then
  # returns a staff scope that acts on the client's behalf — so records seeded with
  # it are stamped with the client's owner_id. Gives them a demo password so they can
  # sign in (provisioning creates the account passwordless).
  def individual(admin, pool, email, first, last) do
    {:ok, result} =
      Fleetms.Provisioning.provision_client(
        %{
          account_type: "individual",
          client_email: email,
          contact_name: "#{first} #{last}",
          contact_email: email
        },
        admin
      )

    Ash.Seed.update!(result.client_user, %{hashed_password: Bcrypt.hash_pwd_salt("password1234")})

    {result.client_user, Scope.on_behalf_of(Scope.new(admin, pool, true), result.client_user.id)}
  end

  # A username-only member (driver/mechanic), provisioned by the owner.
  def member(scope, username, first, last) do
    {:ok, user} =
      Fleetms.Membership.create_member_with_username(
        %{
          username: username,
          password: "password1234",
          password_confirmation: "password1234",
          profile: %{first_name: first, last_name: last}
        },
        scope.organization,
        scope.user
      )

    user
  end

  def role(scope, name) do
    {:ok, role} =
      Fleetms.Permissions.create_role(%{"name" => name}, scope.organization, scope.user)

    role
  end

  def assign_role(scope, user, role) do
    Fleetms.Permissions.assign_role(user.id, role.id, scope.organization, scope.user)
  end

  # --- vehicles ---
  def make_model(scope, make_name, model_name) do
    make = VehicleManagement.upsert_vehicle_make!(%{name: make_name}, scope: scope)

    model =
      VehicleManagement.upsert_vehicle_model!(
        %{name: model_name, vehicle_make_id: make.id},
        scope: scope
      )

    model
  end

  # Copies a bundled placeholder into storage under a unique key, returning the key.
  def store(file) do
    key = "seeds/#{Ecto.UUID.generate()}-#{file}"
    {:ok, _} = Fleetms.Storage.put(key, Path.join(@assets_dir, file))
    key
  end

  def asset_for(:tractor), do: "tractor"
  def asset_for(:truck), do: "truck"
  def asset_for(:dump), do: "truck"
  def asset_for(:pickup), do: "pickup"
  def asset_for(:van), do: "van"
  def asset_for(_), do: "sedan"

  def vehicle(scope, model, attrs, image) do
    base = asset_for(image)
    image_key = store("#{base}.png")
    thumb_key = store("#{base}_thumb.png")

    vehicle =
      VehicleManagement.create_vehicle!(
        Map.merge(attrs, %{
          vehicle_model_id: model.id,
          primary_image_key: image_key,
          primary_thumbnail_key: thumb_key
        }),
        scope: scope
      )

    VehicleManagement.create_vehicle_photo!(
      %{
        vehicle_id: vehicle.id,
        image_key: image_key,
        thumbnail_key: thumb_key,
        caption: "#{attrs.name} — front view"
      },
      scope: scope
    )

    add_document(scope, vehicle, "insurance_certificate.pdf", "Insurance certificate")
    add_document(scope, vehicle, "registration_book.pdf", "Registration (white book)")
    vehicle
  end

  def add_document(scope, vehicle, file, caption) do
    key = store(file)
    size = File.stat!(Path.join(@assets_dir, file)).size

    VehicleManagement.create_vehicle_document!(
      %{
        vehicle_id: vehicle.id,
        filename: file,
        storage_key: key,
        content_type: "application/pdf",
        byte_size: size,
        caption: caption
      },
      scope: scope
    )
  end

  def assign(scope, vehicle, member, days) do
    VehicleManagement.create_vehicle_assignment!(
      %{vehicle_id: vehicle.id, assignee_id: member.id, start_datetime: ago(days)},
      scope: scope
    )
  end

  # --- drivers (people who operate vehicles without an app login) ---
  def driver(scope, first, last, opts \\ []) do
    Drivers.create_driver!(
      %{
        first_name: first,
        last_name: last,
        phone: opts[:phone],
        license_number: opts[:license_number],
        license_class: opts[:license_class] || "CE",
        license_expiry: opts[:license_expiry],
        status: :active
      },
      scope: scope
    )
  end

  # Assign a vehicle to a driver record (rather than a member).
  def assign_driver(scope, vehicle, driver, days) do
    VehicleManagement.create_vehicle_assignment!(
      %{vehicle_id: vehicle.id, driver_id: driver.id, start_datetime: ago(days)},
      scope: scope
    )
  end

  # --- contacts (the external address book) ---
  def contact(scope, name, type, opts \\ []) do
    Contacts.create_contact!(
      %{
        name: name,
        contact_type: type,
        company: opts[:company],
        title: opts[:title],
        phone: opts[:phone],
        email: opts[:email],
        notes: opts[:notes]
      },
      scope: scope
    )
  end

  # --- expenses (non-fuel, non-work-order costs; feed the TCO report) ---
  def expense(scope, vehicle, category, amount, days, description, opts \\ []) do
    Expenses.create_expense!(
      %{
        vehicle_id: vehicle.id,
        category: category,
        amount: zmw(amount),
        expense_date: days_ago(days),
        description: description,
        vendor_id: opts[:vendor_id]
      },
      scope: scope
    )
  end

  def renewal(scope, vehicle, type, due_date) do
    rt = VehicleManagement.upsert_renewal_type!(%{name: type}, scope: scope)

    VehicleManagement.create_vehicle_renewal!(
      %{vehicle_id: vehicle.id, renewal_type_id: rt.id, due_date: due_date},
      scope: scope
    )
  end

  # --- fuel ---
  def fuel(scope, vehicle, entries) do
    Enum.each(entries, fn {days, odo, litres, cost} ->
      FuelManagement.create_fuel_entry!(
        %{
          vehicle_id: vehicle.id,
          refueled_at: ago(days),
          odometer: dec(odo),
          quantity: dec(litres),
          cost: zmw(cost),
          fuel_type: :diesel
        },
        scope: scope
      )
    end)
  end

  # --- issues ---
  def issue(scope, vehicle, title, priority, opts \\ []) do
    VehicleIssues.create_issue!(
      %{
        vehicle_id: vehicle.id,
        title: title,
        description: opts[:description],
        priority: priority,
        reported_at: ago(opts[:days_ago] || 3),
        tags: opts[:tags] || []
      },
      scope: scope
    )
  end

  # --- inventory ---
  def part(scope, category, part_number, name, cost, opts \\ []) do
    cat = Inventory.upsert_part_category!(%{name: category}, scope: scope)

    Inventory.create_part!(
      %{
        part_number: part_number,
        name: name,
        category_id: cat.id,
        unit_cost: zmw(cost),
        track_inventory: true,
        quantity_threshold: dec(opts[:threshold] || 4)
      },
      scope: scope
    )
  end

  def stock(scope, part, location, qty) do
    Inventory.set_part_stock!(
      %{part_id: part.id, inventory_location_id: location.id, quantity: dec(qty)},
      scope: scope
    )
  end

  # --- maintenance ---
  def service_task(scope, name, opts \\ []) do
    Maintenance.create_service_task!(
      %{name: name, description: opts[:description]},
      scope: scope
    )
  end

  @doc """
  Creates a service group over the given vehicles. `schedules` is a list of
  `{service_task, mileage_interval}` tuples that become the group's schedule lines
  (and, via the sync change, a reminder per vehicle × line).
  """
  def service_group(scope, name, vehicles, schedules, opts \\ []) do
    Maintenance.create_service_group!(
      %{
        name: name,
        description: opts[:description],
        vehicle_ids: Enum.map(vehicles, & &1.id),
        schedules:
          Enum.map(schedules, fn {task, interval} ->
            %{service_task_id: task.id, mileage_interval: dec(interval)}
          end)
      },
      scope: scope
    )
  end

  def reminder(scope, vehicle, task, interval) do
    Maintenance.create_service_reminder!(
      %{vehicle_id: vehicle.id, service_task_id: task.id, mileage_interval: dec(interval)},
      scope: scope
    )
  end

  # --- inspections ---
  def dvir_version(scope) do
    schema = %{
      "sections" => [
        %{
          "id" => "exterior",
          "title" => "Exterior & tyres",
          "items" => [
            %{
              "id" => "lights",
              "label" => "Lights & indicators",
              "config" => %{"type" => "pass_fail", "comment_on" => "fail"}
            },
            %{
              "id" => "tyres",
              "label" => "Tyres & wheels",
              "config" => %{"type" => "pass_fail", "comment_on" => "fail", "photo_on" => "fail"}
            },
            %{
              "id" => "mirrors",
              "label" => "Mirrors & glass",
              "config" => %{"type" => "pass_fail"}
            }
          ]
        },
        %{
          "id" => "engine",
          "title" => "Engine & cab",
          "items" => [
            %{
              "id" => "odometer",
              "label" => "Odometer reading",
              "config" => %{"type" => "meter", "unit" => "km", "must_increase" => true}
            },
            %{
              "id" => "brakes",
              "label" => "Brakes",
              "config" => %{"type" => "pass_fail", "comment_on" => "fail"}
            },
            %{"id" => "seatbelts", "label" => "Seatbelts", "config" => %{"type" => "pass_fail"}},
            %{
              "id" => "notes",
              "label" => "Driver notes",
              "config" => %{"type" => "text", "multiline" => true}
            }
          ]
        }
      ]
    }

    form =
      %{title: "Daily Vehicle Inspection (DVIR)"}
      |> Inspections.create_inspection_form!(scope: scope)
      |> then(&Inspections.update_inspection_form!(&1, %{draft_schema: schema}, scope: scope))
      |> then(&Inspections.publish_inspection_form!(&1, scope: scope))

    [version | _] = Inspections.get_inspection_form!(form.id, scope: scope).versions
    {form, version}
  end

  def submit_inspection(scope, version, vehicle, answers) do
    Inspections.submit_inspection!(
      %{vehicle_id: vehicle.id, inspection_form_version_id: version.id, answers: answers},
      scope: scope
    )
  end

  # Upsert a platform subscription plan by its stable `code`.
  def plan(attrs) do
    Fleetms.Billing.create_plan!(attrs,
      authorize?: false,
      upsert?: true,
      upsert_identity: :unique_code
    )
  end

  # =========================================================================
  # Historical generators — spread believable records across a vehicle's whole
  # life (years), so the dashboard, reports and cost-of-ownership have real
  # depth. Dates are relative to "now", odometers interpolate from purchase to
  # the current mileage, and fuel prices rise toward the present (ZMW/litre).
  # =========================================================================

  # A rough ZMW diesel price for `days` ago: ~33 now, trending down into the past.
  defp fuel_price(days), do: Float.round(max(33.0 - 2.6 * (days / 365.0), 11.0), 2)

  @doc "Monthly fuel entries from `start_days` ago (odometer `start_odo`) up to now (`end_odo`)."
  def fuel_history(scope, vehicle, start_days, start_odo, end_odo, l_per_100km) do
    months = max(div(start_days, 30), 1)
    total_km = end_odo - start_odo

    entries =
      for i <- 1..months do
        days = max(start_days - i * 30, 1)
        odo = round(start_odo + total_km * i / months)
        prev_odo = round(start_odo + total_km * (i - 1) / months)
        km = max(odo - prev_odo, 1)
        litres = max(round(km * l_per_100km / 100), 1)
        cost = :erlang.float_to_binary(litres * fuel_price(days), decimals: 2)
        {days, odo, litres, cost}
      end

    fuel(scope, vehicle, entries)
  end

  @doc "A handful of non-fuel expenses per year across the vehicle's life (feeds the TCO report)."
  def expense_history(scope, vehicle, start_days) do
    years = max(div(start_days, 365), 1)

    kinds = [
      {:toll, "Highway tolls", 150, 450},
      {:fine, "Traffic fine", 200, 900},
      {:cleaning, "Wash & valet", 120, 320},
      {:parking, "Depot parking", 80, 220}
    ]

    for y <- 0..(years - 1), {cat, desc, lo, hi} <- kinds do
      days = start_days - y * 365 - :rand.uniform(300)
      amount = lo + :rand.uniform(hi - lo)
      if days > 0, do: expense(scope, vehicle, cat, "#{amount}.00", days, desc)
    end

    :ok
  end

  # One completed work order at a point in the past (cost-only parts — no stock draw,
  # so history never fights the current inventory levels).
  defp completed_service(scope, vehicle, mechanic, task, days, odo, part_lines) do
    Maintenance.create_work_order!(
      %{
        vehicle_id: vehicle.id,
        description: "Scheduled service — #{task.name}",
        repair_category: :preventive,
        issued_at: ago(days),
        mileage: dec(odo),
        assigned_to_id: mechanic.id,
        work_order_service_tasks: [
          %{service_task_id: task.id, work_order_service_task_parts: part_lines}
        ]
      },
      scope: scope
    )
    |> Maintenance.start_work_order!(scope: scope)
    |> Maintenance.complete_work_order!(scope: scope)
  end

  @doc "Completed services roughly every ~6 months across the vehicle's life."
  def service_history(scope, vehicle, mechanic, task, start_days, start_odo, end_odo, part_lines) do
    n = max(div(start_days, 180), 1)
    total_km = end_odo - start_odo

    for i <- 1..n do
      days = start_days - i * 180
      odo = round(start_odo + total_km * i / n)
      if days > 0, do: completed_service(scope, vehicle, mechanic, task, days, odo, part_lines)
    end

    :ok
  end
end

# ---------------------------------------------------------------------------

# Platform subscription plans — the product catalogue. Independent of the demo
# org guard below and upserted by `code`, so this stays current on every run.
Seeds.plan(%{
  code: "individual",
  name: "Starter (Individual)",
  description: "For owner-operators with a handful of vehicles.",
  interval: :month,
  price: Seeds.zmw(150),
  price_per_vehicle: Seeds.zmw(50),
  included_vehicles: 1,
  max_vehicles: 5,
  trial_days: 14
})

Seeds.plan(%{
  code: "fleet",
  name: "Fleet (Business)",
  description: "Growing fleets, billed per vehicle each month.",
  interval: :month,
  price: Seeds.zmw(500),
  price_per_vehicle: Seeds.zmw(120)
})

Seeds.plan(%{
  code: "fleet-annual",
  name: "Fleet (Business, Annual)",
  description: "The Fleet plan billed yearly — two months free.",
  interval: :year,
  price: Seeds.zmw(5000),
  price_per_vehicle: Seeds.zmw(1200)
})

IO.puts("[seeds] ✓ Billing plans (individual, fleet, fleet-annual)")

# ---------------------------------------------------------------------------

if Accounts.list_organizations!(authorize?: false) != [] do
  IO.puts("\n[seeds] Organizations already exist — skipping demo seed.\n")
else
  IO.puts("\n[seeds] Seeding demo data (this creates tenant schemas, give it a moment)…")

  # Platform staff account (reaches /admin across all orgs).
  admin = Seeds.platform_admin("admin@fleetms.example", "Platform", "Admin")

  # The hidden individuals pool — one shared org/schema all individual clients live
  # in (owned/run by staff). Created up front so it exists before any are provisioned.
  pool = Fleetms.Individuals.ensure_pool!(admin)

  # =========================================================================
  # 1) Corporate fleet — Kabwe Haulage Ltd
  # =========================================================================
  {_owner, _org, s} =
    Seeds.owner("manager@kabwehaulage.example", "Mwila", "Bwalya", "Kabwe Haulage Ltd")

  driver_phiri = Seeds.member(s, "phiri", "Joseph", "Phiri")
  driver_tembo = Seeds.member(s, "tembo", "Grace", "Tembo")
  mechanic = Seeds.member(s, "sakala", "Peter", "Sakala")

  Seeds.assign_role(s, mechanic, Seeds.role(s, "Mechanic"))
  Seeds.assign_role(s, driver_phiri, Seeds.role(s, "Driver"))

  # Makes / models
  howo = Seeds.make_model(s, "Sinotruk", "HOWO A7")
  fuso = Seeds.make_model(s, "Mitsubishi Fuso", "Canter")
  actros = Seeds.make_model(s, "Mercedes-Benz", "Actros 2645")
  hilux = Seeds.make_model(s, "Toyota", "Hilux")
  dmax = Seeds.make_model(s, "Isuzu", "D-Max")
  hiace = Seeds.make_model(s, "Toyota", "Hiace")

  v_howo =
    Seeds.vehicle(
      s,
      howo,
      %{
        name: "Howo Tipper 1",
        type: :"Dump Truck",
        category: :"Commercial Trucks",
        body_style: :Truck,
        license_plate: "BAD 4521",
        vin: "LZZ5BBSD1MA100231",
        year: 2021,
        color: "Yellow",
        mileage: Seeds.dec(260_000),
        purchase_date: Seeds.days_ago(1800),
        purchase_price: Decimal.new("1450000"),
        status: :Active
      },
      :dump
    )

  v_actros =
    Seeds.vehicle(
      s,
      actros,
      %{
        name: "Actros Hauler",
        type: :"Tractor Trailer",
        category: :"Commercial Trucks",
        body_style: :Truck,
        license_plate: "BAB 9087",
        vin: "WDB9634031L900112",
        year: 2019,
        color: "White",
        mileage: Seeds.dec(520_000),
        purchase_date: Seeds.days_ago(2500),
        purchase_price: Decimal.new("2100000"),
        status: :Active
      },
      :tractor
    )

  v_fuso =
    Seeds.vehicle(
      s,
      fuso,
      %{
        name: "Canter Distributor",
        type: :Truck,
        category: :"Light Commercial",
        body_style: :Truck,
        license_plate: "ACJ 1123",
        vin: "JL6BBG1A0KK012345",
        year: 2020,
        color: "White",
        mileage: Seeds.dec(180_000),
        purchase_date: Seeds.days_ago(2100),
        purchase_price: Decimal.new("620000"),
        status: :Maintenance
      },
      :truck
    )

  v_hilux =
    Seeds.vehicle(
      s,
      hilux,
      %{
        name: "Hilux Supervisor",
        type: :"Pickup Truck",
        category: :"Light Commercial",
        body_style: :"Pickup Truck",
        license_plate: "BAC 3390",
        vin: "AHTFR22G106512377",
        year: 2022,
        color: "Silver",
        mileage: Seeds.dec(95_000),
        purchase_date: Seeds.days_ago(1500),
        purchase_price: Decimal.new("780000"),
        status: :Active
      },
      :pickup
    )

  v_dmax =
    Seeds.vehicle(
      s,
      dmax,
      %{
        name: "D-Max Site 2",
        type: :"Pickup Truck",
        category: :"Light Commercial",
        body_style: :"Pickup Truck",
        license_plate: "ALE 7742",
        vin: "MPATFS85JJT000998",
        year: 2018,
        color: "Grey",
        mileage: Seeds.dec(210_000),
        purchase_date: Seeds.days_ago(2900),
        purchase_price: Decimal.new("510000"),
        status: :"Out-of-Service"
      },
      :pickup
    )

  v_hiace =
    Seeds.vehicle(
      s,
      hiace,
      %{
        name: "Hiace Crew Bus",
        type: :Van,
        category: :"Light Commercial",
        body_style: :Van,
        license_plate: "BAA 2210",
        vin: "JTFHS02P900045612",
        year: 2020,
        color: "White",
        mileage: Seeds.dec(195_000),
        purchase_date: Seeds.days_ago(2100),
        purchase_price: Decimal.new("560000"),
        status: :Active
      },
      :van
    )

  corporate_vehicles = [v_howo, v_actros, v_fuso, v_hilux, v_dmax, v_hiace]

  # Assignments to members (users with a login)
  Seeds.assign(s, v_howo, driver_phiri, 120)
  Seeds.assign(s, v_actros, driver_tembo, 200)
  Seeds.assign(s, v_hiace, driver_phiri, 40)

  # Drivers — people who operate vehicles but have no app login. One licence expires
  # soon so it surfaces on the calendar; one has already lapsed.
  drv_mumba =
    Seeds.driver(s, "Chola", "Mumba",
      phone: "+260 97 555 0101",
      license_number: "ZM-DL-88231",
      license_expiry: Seeds.days_ahead(25)
    )

  drv_zulu =
    Seeds.driver(s, "Agnes", "Zulu",
      phone: "+260 96 555 0102",
      license_number: "ZM-DL-77410",
      license_expiry: Seeds.days_ago(6)
    )

  _drv_banda =
    Seeds.driver(s, "Felix", "Banda",
      phone: "+260 95 555 0103",
      license_number: "ZM-DL-66190",
      license_expiry: Seeds.days_ahead(310)
    )

  # A vehicle assigned to a driver rather than a member.
  Seeds.assign_driver(s, v_dmax, drv_mumba, 30)
  _ = drv_zulu

  # Renewals — a spread of overdue / due-soon / future
  # Renewals — every vehicle carries the three statutory ones, with a spread of
  # due dates (some overdue, some due soon, some comfortable) so the renewals list
  # and its filters show the full range of states.
  Seeds.renewal(s, v_howo, "Insurance", Seeds.days_ahead(20))
  Seeds.renewal(s, v_howo, "Road Tax", Seeds.days_ago(5))
  Seeds.renewal(s, v_howo, "Fitness Certificate", Seeds.days_ahead(95))
  Seeds.renewal(s, v_actros, "Insurance", Seeds.days_ahead(75))
  Seeds.renewal(s, v_actros, "Fitness Certificate", Seeds.days_ahead(12))
  Seeds.renewal(s, v_actros, "Road Tax", Seeds.days_ahead(210))
  Seeds.renewal(s, v_fuso, "Insurance", Seeds.days_ago(2))
  Seeds.renewal(s, v_fuso, "Road Tax", Seeds.days_ahead(45))
  Seeds.renewal(s, v_fuso, "Fitness Certificate", Seeds.days_ago(12))
  Seeds.renewal(s, v_hilux, "Road Tax", Seeds.days_ahead(150))
  Seeds.renewal(s, v_hilux, "Insurance", Seeds.days_ahead(8))
  Seeds.renewal(s, v_hilux, "Fitness Certificate", Seeds.days_ahead(260))
  Seeds.renewal(s, v_dmax, "Insurance", Seeds.days_ahead(33))
  Seeds.renewal(s, v_dmax, "Road Tax", Seeds.days_ago(9))
  Seeds.renewal(s, v_hiace, "Fitness Certificate", Seeds.days_ahead(30))
  Seeds.renewal(s, v_hiace, "Insurance", Seeds.days_ahead(120))
  Seeds.renewal(s, v_hiace, "Road Tax", Seeds.days_ahead(3))

  # Fuel + expense history across each vehicle's life (years of data for the
  # fuel/economy and cost-of-ownership reports). Params: start_days_ago, start_odo,
  # end_odo (= current mileage), litres/100km.
  Seeds.fuel_history(s, v_howo, 1800, 0, 260_000, 40)
  Seeds.fuel_history(s, v_actros, 2500, 0, 520_000, 35)
  Seeds.fuel_history(s, v_fuso, 2100, 0, 180_000, 18)
  Seeds.fuel_history(s, v_hilux, 1500, 0, 95_000, 11)
  Seeds.fuel_history(s, v_dmax, 2900, 0, 210_000, 12)
  Seeds.fuel_history(s, v_hiace, 2100, 0, 195_000, 13)

  Seeds.expense_history(s, v_howo, 1800)
  Seeds.expense_history(s, v_actros, 2500)
  Seeds.expense_history(s, v_fuso, 2100)
  Seeds.expense_history(s, v_hilux, 1500)
  Seeds.expense_history(s, v_dmax, 2900)
  Seeds.expense_history(s, v_hiace, 2100)

  # Tags
  Seeds.assign_role(s, driver_tembo, Seeds.role(s, "Long-haul"))
  long_haul = Tagging.create_tag!(%{name: "Long-haul", color: :blue}, scope: s)
  Tagging.create_tagging!(%{tag_id: long_haul.id, vehicle_id: v_actros.id}, scope: s)
  Tagging.create_tagging!(%{tag_id: long_haul.id, vehicle_id: v_howo.id}, scope: s)

  # Issues — a mix of open and resolved, spread over time so the status/priority
  # filters and the sortable columns all have something to work with.
  Seeds.issue(s, v_fuso, "Coolant leak from lower hose", :High,
    description: "Puddle under engine after morning run. Losing coolant.",
    days_ago: 4,
    tags: ["Urgent"]
  )

  Seeds.issue(s, v_howo, "Cracked windscreen (passenger side)", :Medium, days_ago: 9)
  Seeds.issue(s, v_dmax, "Gearbox noise in 3rd gear", :High, days_ago: 15, tags: ["Driveline"])
  Seeds.issue(s, v_hilux, "Air-con not cooling", :Low, days_ago: 2)
  Seeds.issue(s, v_actros, "ABS warning light intermittent", :Medium, days_ago: 6)
  Seeds.issue(s, v_howo, "Clutch slipping under load", :High, days_ago: 11, tags: ["Driveline"])
  Seeds.issue(s, v_hiace, "Sliding door sticks", :Low, days_ago: 1)
  Seeds.issue(s, v_fuso, "Headlight aim too low", :Low, days_ago: 7)
  Seeds.issue(s, v_dmax, "Reverse camera blank", :Medium, days_ago: 18)

  # A handful resolved, at various points in the past, so history isn't empty.
  for {vehicle, title, pri, days, comment} <- [
        {v_hiace, "Worn wiper blades", :Low, 20, "Replaced both blades."},
        {v_actros, "Brake pads at wear limit", :High, 45, "Fitted new front pad set."},
        {v_hilux, "Slow puncture on rear left", :Medium, 70, "Patched and rebalanced."},
        {v_howo, "Battery not holding charge", :Medium, 120, "Replaced with new N150."},
        {v_fuso, "Loose exhaust bracket", :Low, 200, "Re-welded and clamped."}
      ] do
    issue = Seeds.issue(s, vehicle, title, pri, days_ago: days)
    VehicleIssues.resolve_issue!(issue, %{resolve_comments: comment}, scope: s)
  end

  # Inventory: locations, parts, stock
  main_store = Inventory.create_inventory_location!(%{name: "Main Store — Lusaka"}, scope: s)
  kitwe_depot = Inventory.create_inventory_location!(%{name: "Kitwe Depot"}, scope: s)

  oil_filter = Seeds.part(s, "Filters", "OF-1042", "Oil filter (HOWO)", "180.00")
  air_filter = Seeds.part(s, "Filters", "AF-2201", "Air filter element", "260.00")
  brake_pads = Seeds.part(s, "Brakes", "BP-5567", "Brake pad set (front)", "1350.00")
  fan_belt = Seeds.part(s, "Belts", "FB-3300", "Fan belt", "220.00", threshold: 6)
  tyre = Seeds.part(s, "Tyres", "TY-1200R20", "Tyre 1200R20", "3200.00", threshold: 4)
  battery = Seeds.part(s, "Electrical", "BT-N150", "Battery N150", "2100.00")

  Seeds.stock(s, oil_filter, main_store, 24)
  Seeds.stock(s, air_filter, main_store, 12)
  Seeds.stock(s, brake_pads, main_store, 8)
  Seeds.stock(s, fan_belt, main_store, 2)
  Seeds.stock(s, tyre, kitwe_depot, 3)
  Seeds.stock(s, battery, main_store, 5)

  # A broader catalogue so the parts list (and its filters/sorting) has volume.
  # {category, part_number, name, cost, store, qty} — qty nil = no stock line yet.
  for {cat, pn, name, cost, loc, qty} <- [
        {"Filters", "FF-7781", "Fuel filter (common-rail)", "320.00", main_store, 15},
        {"Filters", "CF-4410", "Cabin pollen filter", "140.00", main_store, 9},
        {"Brakes", "BP-5568", "Brake pad set (rear)", "1180.00", main_store, 6},
        {"Brakes", "BD-9902", "Brake disc rotor", "1950.00", kitwe_depot, 4},
        {"Brakes", "BF-0500", "Brake fluid DOT4 (1L)", "95.00", main_store, 20},
        {"Belts", "TB-2250", "Timing belt kit", "1450.00", main_store, 3},
        {"Tyres", "TY-7016C", "Tyre 7.00R16 (light truck)", "1650.00", kitwe_depot, 8},
        {"Tyres", "TY-26565", "Tyre 265/65R17 (pickup)", "1850.00", main_store, 6},
        {"Electrical", "AL-120A", "Alternator 120A", "3400.00", main_store, 2},
        {"Electrical", "GP-0008", "Glow plug (set of 4)", "480.00", main_store, 7},
        {"Electrical", "HB-H4", "Headlight bulb H4", "65.00", main_store, 30},
        {"Lubricants", "EO-15W40", "Engine oil 15W-40 (20L)", "890.00", main_store, 18},
        {"Lubricants", "CL-RED", "Coolant concentrate (5L)", "210.00", main_store, 14},
        {"Lubricants", "GL-80W90", "Gear oil 80W-90 (5L)", "320.00", kitwe_depot, 10},
        {"Suspension", "SA-FR01", "Shock absorber (front)", "1250.00", main_store, 5},
        {"Suspension", "LS-REAR", "Leaf spring (rear)", "2600.00", kitwe_depot, 2},
        {"Body", "WB-2200", "Wiper blade (pair)", "180.00", main_store, 22},
        {"Body", "SM-LEFT", "Side mirror assembly (LH)", "720.00", main_store, 4}
      ] do
    part = Seeds.part(s, cat, pn, name, cost)
    if qty, do: Seeds.stock(s, part, loc, qty)
  end

  # Service tasks — a realistic catalogue of recurring maintenance work.
  oil_change = Seeds.service_task(s, "Engine oil & filter change")
  brake_check = Seeds.service_task(s, "Brake inspection")
  tyre_rotation = Seeds.service_task(s, "Tyre rotation")

  air_filter_task =
    Seeds.service_task(s, "Air filter replacement",
      description: "Replace engine air filter element."
    )

  fuel_filter_task = Seeds.service_task(s, "Fuel filter replacement")
  coolant_task = Seeds.service_task(s, "Coolant flush & refill")
  gearbox_task = Seeds.service_task(s, "Gearbox oil change")
  diff_task = Seeds.service_task(s, "Differential oil change")
  wheel_align = Seeds.service_task(s, "Wheel alignment & balancing")
  battery_check = Seeds.service_task(s, "Battery & charging system check")
  suspension_task = Seeds.service_task(s, "Suspension inspection")
  aircon_task = Seeds.service_task(s, "Air-conditioning service")
  _ = [diff_task, battery_check, suspension_task, aircon_task]

  # Loose reminders (not tied to a group, and not duplicating any group line's
  # vehicle × task — those are unique).
  Seeds.reminder(s, v_howo, brake_check, 30_000)
  Seeds.reminder(s, v_actros, wheel_align, 40_000)
  Seeds.reminder(s, v_dmax, coolant_task, 60_000)

  # Service groups — shared maintenance programmes applied to many vehicles at
  # once. Each schedule line fans out to a reminder per member vehicle.
  Seeds.service_group(
    s,
    "Heavy truck programme",
    [v_howo, v_actros, v_fuso],
    [
      {oil_change, 15_000},
      {air_filter_task, 30_000},
      {fuel_filter_task, 45_000},
      {gearbox_task, 90_000}
    ],
    description: "Preventive schedule for the long-haul truck fleet."
  )

  Seeds.service_group(
    s,
    "Light vehicle programme",
    [v_hilux, v_dmax, v_hiace],
    [{oil_change, 10_000}, {tyre_rotation, 10_000}, {brake_check, 20_000}],
    description: "Preventive schedule for pickups and vans."
  )

  # Completed service history (cost-only parts, so it never fights current stock).
  svc_parts = [
    %{part_id: oil_filter.id, quantity: Seeds.dec(1), unit_cost: Seeds.zmw("180.00")},
    %{part_id: air_filter.id, quantity: Seeds.dec(1), unit_cost: Seeds.zmw("260.00")}
  ]

  Seeds.service_history(s, v_howo, mechanic, oil_change, 1800, 0, 260_000, svc_parts)
  Seeds.service_history(s, v_actros, mechanic, oil_change, 2500, 0, 520_000, svc_parts)
  Seeds.service_history(s, v_fuso, mechanic, oil_change, 2100, 0, 180_000, svc_parts)
  Seeds.service_history(s, v_hilux, mechanic, oil_change, 1500, 0, 95_000, svc_parts)
  Seeds.service_history(s, v_dmax, mechanic, oil_change, 2900, 0, 210_000, svc_parts)
  Seeds.service_history(s, v_hiace, mechanic, oil_change, 2100, 0, 195_000, svc_parts)

  # Work orders
  # Completed WO — draws stock down from Main Store (oil filter + labour part)
  wo_done =
    Maintenance.create_work_order!(
      %{
        vehicle_id: v_howo.id,
        description: "Scheduled service — oil & filter change",
        repair_category: :preventive,
        issued_at: Seeds.ago(12),
        assigned_to_id: mechanic.id,
        work_order_service_tasks: [
          %{
            service_task_id: oil_change.id,
            work_order_service_task_parts: [
              %{
                part_id: oil_filter.id,
                inventory_location_id: main_store.id,
                quantity: Seeds.dec(1),
                unit_cost: Seeds.zmw("180.00")
              },
              %{
                part_id: air_filter.id,
                inventory_location_id: main_store.id,
                quantity: Seeds.dec(1),
                unit_cost: Seeds.zmw("260.00")
              }
            ]
          }
        ]
      },
      scope: s
    )

  wo_done |> Maintenance.start_work_order!(scope: s) |> Maintenance.complete_work_order!(scope: s)

  # In-progress WO linked to the coolant issue
  Maintenance.create_work_order!(
    %{
      vehicle_id: v_fuso.id,
      description: "Investigate and repair coolant leak",
      repair_category: :corrective,
      issued_at: Seeds.ago(3),
      assigned_to_id: mechanic.id,
      work_order_service_tasks: [%{service_task_id: brake_check.id}]
    },
    scope: s
  )
  |> Maintenance.start_work_order!(scope: s)

  # Open WO
  Maintenance.create_work_order!(
    %{
      vehicle_id: v_dmax.id,
      description: "Gearbox diagnosis",
      repair_category: :corrective,
      issued_at: Seeds.ago(1)
    },
    scope: s
  )

  # Inspections — a DVIR form with a pass and a fail submission
  {form, version} = Seeds.dvir_version(s)

  Seeds.submit_inspection(s, version, v_hilux, [
    %{"item_id" => "lights", "value" => "pass"},
    %{"item_id" => "tyres", "value" => "pass"},
    %{"item_id" => "mirrors", "value" => "pass"},
    %{"item_id" => "odometer", "value" => "95000"},
    %{"item_id" => "brakes", "value" => "pass"},
    %{"item_id" => "seatbelts", "value" => "pass"},
    %{"item_id" => "notes", "value" => "All good on the morning check."}
  ])

  Seeds.submit_inspection(s, version, v_howo, [
    %{"item_id" => "lights", "value" => "pass"},
    %{"item_id" => "tyres", "value" => "fail", "comment" => "Front left tyre low tread."},
    %{"item_id" => "mirrors", "value" => "pass"},
    %{"item_id" => "odometer", "value" => "260000"},
    %{"item_id" => "brakes", "value" => "fail", "comment" => "Spongy pedal, needs bleed."},
    %{"item_id" => "seatbelts", "value" => "pass"},
    %{"item_id" => "notes", "value" => "Reported to workshop."}
  ])

  # Inspection schedule (populates the Schedules page)
  Inspections.create_inspection_schedule!(
    %{
      name: "Daily DVIR — Howo Tipper",
      interval_days: 1,
      inspection_form_id: form.id,
      vehicle_id: v_howo.id,
      assigned_to_id: driver_phiri.id
    },
    scope: s
  )

  # Contacts — the external address book (vendors, insurers, inspectors, towing)
  Seeds.contact(s, "Themba Nkandu", :insurer,
    company: "Madison General Insurance",
    title: "Fleet Claims Officer",
    phone: "+260 211 555 200",
    email: "claims@madison.example",
    notes: "Handles motor claims for the fleet policy."
  )

  Seeds.contact(s, "RTSA Inspectorate", :inspector,
    company: "Road Transport & Safety Agency",
    phone: "+260 211 555 311",
    notes: "Fitness certificate inspections — book a week ahead."
  )

  Seeds.contact(s, "Grace Mulenga", :supplier,
    company: "Copperbelt Truck Parts",
    title: "Parts Manager",
    phone: "+260 97 555 400",
    email: "grace@cbparts.example"
  )

  Seeds.contact(s, "Lusaka 24hr Towing", :towing,
    phone: "+260 96 555 911",
    notes: "Recovery + heavy towing, Great East Road."
  )

  # Expenses — non-fuel, non-work-order costs that feed the cost-of-ownership report
  Seeds.expense(s, v_howo, :insurance, "8500.00", 40, "Annual motor policy — Q3 instalment")
  Seeds.expense(s, v_howo, :toll, "320.00", 6, "Kafue toll — Lusaka run")
  Seeds.expense(s, v_actros, :insurance, "9800.00", 55, "Annual motor policy — heavy goods")
  Seeds.expense(s, v_actros, :fine, "450.00", 12, "Overloading fine at weighbridge")
  Seeds.expense(s, v_hilux, :registration, "1200.00", 20, "Registration renewal")
  Seeds.expense(s, v_dmax, :cleaning, "180.00", 3, "Wash & valet")

  IO.puts(
    "[seeds]   ✓ Kabwe Haulage Ltd — #{length(corporate_vehicles)} vehicles + full activity"
  )

  # =========================================================================
  # 2) Individual client — Chanda (managed in the shared individuals pool)
  # =========================================================================
  {_chanda, s2} = Seeds.individual(admin, pool, "chanda@example.com", "Chanda", "Mumba")

  corolla = Seeds.make_model(s2, "Toyota", "Corolla")
  ranger = Seeds.make_model(s2, "Ford", "Ranger")

  v_corolla =
    Seeds.vehicle(
      s2,
      corolla,
      %{
        name: "Corolla (daily)",
        type: :Sedan,
        category: :"Passenger Cars",
        body_style: :Sedan,
        license_plate: "BAK 5521",
        vin: "JTDBR32E620098765",
        year: 2016,
        color: "Blue",
        mileage: Seeds.dec(142_000),
        purchase_date: Seeds.days_ago(1100),
        purchase_price: Decimal.new("165000"),
        status: :Active
      },
      :sedan
    )

  v_ranger =
    Seeds.vehicle(
      s2,
      ranger,
      %{
        name: "Ranger (weekend)",
        type: :"Pickup Truck",
        category: :"Light Commercial",
        body_style: :"Pickup Truck",
        license_plate: "BAL 8843",
        vin: "MNBLMFF50KW345612",
        year: 2019,
        color: "Red",
        mileage: Seeds.dec(88_500),
        purchase_date: Seeds.days_ago(600),
        purchase_price: Decimal.new("420000"),
        status: :Active
      },
      :pickup
    )

  Seeds.renewal(s2, v_corolla, "Insurance", Seeds.days_ahead(18))
  Seeds.renewal(s2, v_corolla, "Road Tax", Seeds.days_ago(3))
  Seeds.renewal(s2, v_ranger, "Insurance", Seeds.days_ahead(60))

  Seeds.fuel(s2, v_corolla, [
    {40, 141_100, 42, "1386.00"},
    {18, 141_600, 40, "1320.00"},
    {3, 142_000, 41, "1353.00"}
  ])

  Seeds.fuel(s2, v_ranger, [{25, 88_000, 65, "2145.00"}, {6, 88_500, 62, "2046.00"}])

  Seeds.issue(s2, v_corolla, "Brake pads squealing", :Medium, days_ago: 5)
  Seeds.issue(s2, v_ranger, "Service light on", :Low, days_ago: 8)

  oil_task = Seeds.service_task(s2, "Engine oil & filter change")
  Seeds.reminder(s2, v_corolla, oil_task, 5_000)
  Seeds.reminder(s2, v_ranger, oil_task, 7_500)

  {_f2, version2} = Seeds.dvir_version(s2)

  Seeds.submit_inspection(s2, version2, v_corolla, [
    %{"item_id" => "lights", "value" => "pass"},
    %{"item_id" => "tyres", "value" => "pass"},
    %{"item_id" => "mirrors", "value" => "pass"},
    %{"item_id" => "odometer", "value" => "142000"},
    %{"item_id" => "brakes", "value" => "fail", "comment" => "Squealing — pads due."},
    %{"item_id" => "seatbelts", "value" => "pass"},
    %{"item_id" => "notes", "value" => "Booked for pad replacement."}
  ])

  IO.puts("[seeds]   ✓ Chanda (individual, in the pool) — 2 vehicles")

  IO.puts("""

  [seeds] Done. Sign in with:
    Platform admin: admin@fleetms.example    / password1234  (→ /admin)
    Corporate     : manager@kabwehaulage.example  / password1234
    Individual    : chanda@example.com            / password1234
    Members (username sign-in): phiri, tembo, sakala  / password1234
  """)
end
