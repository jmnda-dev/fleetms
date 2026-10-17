defmodule FleetmsWeb.DriverLive.Form do
  @moduledoc "Create / edit a driver — an `AshPhoenix.Form` over the driver actions."
  use FleetmsWeb, :live_view

  alias AshPhoenix.Form
  alias Fleetms.Drivers
  alias Fleetms.Drivers.Driver
  alias Fleetms.Drivers.DriverStatus

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, active_link: :drivers)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    scope = socket.assigns.current_scope
    form = Form.for_create(Driver, :create, domain: Drivers, as: "driver", scope: scope)

    socket
    |> assign(page_title: gettext("New driver"))
    |> assign(:form, to_form(form))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    scope = socket.assigns.current_scope

    case Drivers.get_driver(id, scope: scope) do
      {:ok, driver} ->
        form = Form.for_update(driver, :update, domain: Drivers, as: "driver", scope: scope)

        socket
        |> assign(page_title: gettext("Edit driver"))
        |> assign(:form, to_form(form))

      {:error, _} ->
        socket
        |> put_flash(:error, gettext("That driver could not be found."))
        |> push_navigate(to: ~p"/o/#{org(socket)}/drivers")
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      organizations={@organizations}
      unread_notifications_count={@unread_notifications_count}
      recent_notifications={@recent_notifications}
      notifications_open={@notifications_open}
    >
      <.breadcrumbs items={[
        %{label: gettext("Dashboard"), path: ~p"/o/#{org(assigns)}", icon: "fa-house"},
        %{label: gettext("Drivers"), path: ~p"/o/#{org(assigns)}/drivers"},
        %{label: @page_title}
      ]} />

      <.header>
        {@page_title}
        <:subtitle>{gettext("A person who drives your vehicles.")}</:subtitle>
      </.header>

      <.form
        :let={f}
        for={@form}
        id="driver-form"
        phx-change="validate"
        phx-submit="save"
        class="mt-6"
      >
        <div class="rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800">
          <div class="grid gap-4 md:grid-cols-2">
            <.input field={f[:first_name]} label={gettext("First name")} required />
            <.input field={f[:last_name]} label={gettext("Last name")} required />

            <.input field={f[:phone]} label={gettext("Phone")} />
            <.input field={f[:email]} type="email" label={gettext("Email")} />

            <.input field={f[:license_number]} label={gettext("Licence number")} />
            <.input field={f[:license_class]} label={gettext("Licence class")} />

            <.input field={f[:license_expiry]} type="date" label={gettext("Licence expiry")} />
            <.input
              field={f[:status]}
              type="select"
              label={gettext("Status")}
              options={status_options()}
            />

            <div class="md:col-span-2">
              <.input field={f[:notes]} type="textarea" label={gettext("Notes")} />
            </div>
          </div>
        </div>

        <div class="mt-6 flex items-center gap-3">
          <.button type="submit" phx-disable-with={gettext("Saving…")}>
            {gettext("Save driver")}
          </.button>
          <.button variant="secondary" navigate={~p"/o/#{org(assigns)}/drivers"}>
            {gettext("Cancel")}
          </.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"driver" => params}, socket) do
    {:noreply, assign(socket, :form, Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"driver" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, _driver} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Driver saved."))
         |> push_navigate(to: ~p"/o/#{org(socket)}/drivers")}

      {:error, form} ->
        {:noreply,
         socket
         |> assign(:form, form)
         |> put_flash(:error, gettext("Please fix the errors below."))}
    end
  end

  defp status_options do
    Enum.map(DriverStatus.values(), &{&1 |> to_string() |> String.capitalize(), &1})
  end

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
