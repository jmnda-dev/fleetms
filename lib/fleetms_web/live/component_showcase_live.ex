defmodule FleetmsWeb.ComponentShowcaseLive do
  @moduledoc """
  Developer page for testing and debugging `FleetmsWeb.CoreComponents`.

  Every component defined in `core_components.ex` is rendered here in all its
  meaningful configurations (clean state, error state, all variants). This makes
  it easy to spot visual regressions when migrating from DaisyUI to Flowbite.
  """
  use FleetmsWeb, :live_view

  # ---------------------------------------------------------------------------
  # Embedded schema – drives the live-validated form section
  # ---------------------------------------------------------------------------

  defmodule ShowcaseForm do
    @moduledoc false
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :full_name, :string
      field :email, :string
      field :password, :string
      field :age, :integer
      field :bio, :string
      field :role, :string
      field :start_date, :date
      field :agreed, :boolean, default: false
    end

    @role_options [
      {"— Select a role —", ""},
      {"Driver", "driver"},
      {"Mechanic", "mechanic"},
      {"Fleet Manager", "manager"},
      {"Admin", "admin"}
    ]
    def role_options, do: @role_options

    def changeset(data \\ %__MODULE__{}, attrs \\ %{}) do
      data
      |> cast(attrs, [:full_name, :email, :password, :age, :bio, :role, :start_date, :agreed])
      |> validate_required([:full_name, :email, :role], message: "is required")
      |> validate_length(:full_name, min: 2, message: "must be at least 2 characters")
      |> validate_format(:email, ~r/@/, message: "must include @")
      |> validate_number(:age,
        greater_than_or_equal_to: 18,
        less_than_or_equal_to: 99,
        message: "must be between 18 and 99"
      )
    end
  end

  # ---------------------------------------------------------------------------
  # Static demo data
  # ---------------------------------------------------------------------------

  @vehicles [
    %{id: "v1", plate: "AAB 1234", make: "Toyota", model: "Hilux", year: 2021, status: "Active"},
    %{
      id: "v2",
      plate: "XYZ 7890",
      make: "Ford",
      model: "Ranger",
      year: 2019,
      status: "In Service"
    },
    %{id: "v3", plate: "DEF 4567", make: "Isuzu", model: "D-Max", year: 2022, status: "Inactive"}
  ]

  @fleet_summary [
    %{title: "Total Vehicles", value: "42"},
    %{title: "Active Drivers", value: "18"},
    %{title: "Open Service Jobs", value: "5"},
    %{title: "Fuel Cost This Month", value: "$3,840.00"},
    %{title: "Next Scheduled Service", value: "Toyota Hilux (AAB 1234) – in 3 days"}
  ]

  # ---------------------------------------------------------------------------
  # LiveView callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Core Components Showcase")
     |> assign(:live_form, to_form(ShowcaseForm.changeset(), as: :sf))
     |> assign(:vehicles, @vehicles)
     |> assign(:fleet_summary, @fleet_summary)}
  end

  @impl true
  def handle_event("validate", %{"sf" => params}, socket) do
    cs = ShowcaseForm.changeset(%ShowcaseForm{}, params)
    {:noreply, assign(socket, :live_form, to_form(cs, as: :sf, action: :validate))}
  end

  @impl true
  def handle_event("submit_form", %{"sf" => params}, socket) do
    case ShowcaseForm.changeset(%ShowcaseForm{}, params)
         |> Ecto.Changeset.apply_action(:insert) do
      {:ok, _data} ->
        {:noreply,
         socket
         |> put_flash(:info, "Form submitted successfully!")
         |> assign(:live_form, to_form(ShowcaseForm.changeset(), as: :sf))}

      {:error, cs} ->
        {:noreply, assign(socket, :live_form, to_form(cs, as: :sf, action: :validate))}
    end
  end

  @impl true
  def handle_event("show_flash_info", _params, socket),
    do: {:noreply, put_flash(socket, :info, "Fleet sync completed for 42 vehicles.")}

  @impl true
  def handle_event("show_flash_error", _params, socket),
    do: {:noreply, put_flash(socket, :error, "Could not connect to the tracking service.")}

  @impl true
  def handle_event("row_click", %{"vehicle-id" => id}, socket),
    do: {:noreply, put_flash(socket, :info, "Row clicked – vehicle ID: #{id}")}
end
