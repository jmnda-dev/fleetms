defmodule FleetmsWeb.VehicleLive.StatusPresenter do
  @moduledoc """
  Presentation for a vehicle's operational status — the friendly label, badge
  colour and a plain description of what each status *implies* for the fleet — plus
  the status badge and the "change status" modal used on the vehicle list and
  detail pages.

  Single source of truth for status display: the enum values live in
  `Fleetms.VehicleManagement.VehicleStatus`; the human-facing copy lives here.
  """
  use FleetmsWeb, :html

  @statuses [
    %{
      value: :Active,
      label: "Active",
      icon: "fa-circle-check",
      color: "success",
      accent: "text-green-600 dark:text-green-400",
      description:
        "In service and available — can be assigned to drivers, scheduled for inspections, and put on work orders."
    },
    %{
      value: :Maintenance,
      label: "In Shop",
      icon: "fa-wrench",
      color: "warning",
      accent: "text-amber-600 dark:text-amber-400",
      description:
        "Temporarily off the road for scheduled service or repair. Still tracked, but not offered for new driver assignments."
    },
    %{
      value: :"Out-of-Service",
      label: "Out of Service",
      icon: "fa-triangle-exclamation",
      color: "danger",
      accent: "text-red-600 dark:text-red-400",
      description:
        "Not usable right now — breakdown, failed inspection, or awaiting parts. Not offered for new driver assignments."
    },
    %{
      value: :Inactive,
      label: "Inactive",
      icon: "fa-circle-pause",
      color: "gray",
      accent: "text-gray-500 dark:text-gray-400",
      description:
        "Taken out of the active fleet but still owned — stored, seasonal, or decommissioned. Kept for records, out of day-to-day views."
    },
    %{
      value: :Sold,
      label: "Sold / Disposed",
      icon: "fa-hand-holding-dollar",
      color: "gray",
      accent: "text-gray-500 dark:text-gray-400",
      description:
        "No longer owned. Kept only for history — past work orders, costs and inspections. Hidden from every picker."
    }
  ]

  @doc "All statuses with their display metadata, in presentation order."
  def statuses, do: @statuses

  @doc "Metadata for one status value (falls back gracefully for unknown values)."
  def meta(value) do
    Enum.find(@statuses, &(&1.value == value)) ||
      %{
        value: value,
        label: to_string(value),
        color: "gray",
        icon: "fa-circle",
        accent: "",
        description: nil
      }
  end

  def label(value), do: meta(value).label
  def color(value), do: meta(value).color

  @doc "`{label, value_string}` pairs for the status filter checkboxes."
  def filter_options, do: Enum.map(@statuses, &{&1.label, to_string(&1.value)})

  attr :status, :atom, default: nil

  @doc "The status badge, with the friendly label and colour."
  def status_badge(assigns) do
    ~H"""
    <.badge :if={@status} color={color(@status)}>{label(@status)}</.badge>
    <span :if={is_nil(@status)} class="text-body">—</span>
    """
  end

  attr :vehicle, :any, default: nil
  attr :on_select, :string, default: "set_status"
  attr :on_close, :string, default: "close_status"

  @doc """
  The change-status modal — server-driven (renders only when `vehicle` is set, so
  it's immune to the morphdom/Flowbite `hidden`-class issue). Each status is a card
  with its icon, label and description; the current one is marked. Clicking a card
  sends `on_select` with `id` and `status`; the backdrop/✕ send `on_close`.
  """
  def status_modal(assigns) do
    ~H"""
    <div :if={@vehicle} class="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div class="absolute inset-0 bg-gray-900/50" phx-click={@on_close} aria-hidden="true"></div>
      <div class="relative w-full max-w-2xl rounded-base border border-default bg-white p-6 shadow-lg dark:bg-gray-800">
        <div class="mb-4 flex items-center justify-between border-b border-default pb-4">
          <h3 class="text-lg font-medium text-heading">
            {gettext("Change status")} — <span class="text-body">{@vehicle.name}</span>
          </h3>
          <button
            type="button"
            phx-click={@on_close}
            class="inline-flex h-9 w-9 items-center justify-center rounded-base text-body hover:bg-neutral-tertiary hover:text-heading"
          >
            <.icon name="fa-xmark" class="text-lg" />
            <span class="sr-only">{gettext("Close")}</span>
          </button>
        </div>

        <div class="grid gap-3 sm:grid-cols-2">
          <button
            :for={s <- statuses()}
            type="button"
            phx-click={@on_select}
            phx-value-id={@vehicle.id}
            phx-value-status={s.value}
            class={[
              "rounded-lg border p-4 text-left transition hover:border-brand hover:bg-neutral-secondary-medium",
              @vehicle.status == s.value && "border-brand ring-1 ring-brand",
              @vehicle.status != s.value && "border-default"
            ]}
          >
            <div class="flex items-center justify-between">
              <span class="flex items-center gap-2 font-medium text-heading">
                <.icon name={s.icon} class={s.accent} /> {s.label}
              </span>
              <span
                :if={@vehicle.status == s.value}
                class="rounded bg-brand-softer px-2 py-0.5 text-xs font-medium text-fg-brand"
              >
                {gettext("Current")}
              </span>
            </div>
            <p class="mt-2 text-sm text-body">{s.description}</p>
          </button>
        </div>
      </div>
    </div>
    """
  end
end
