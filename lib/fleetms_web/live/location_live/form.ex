defmodule FleetmsWeb.LocationLive.Form do
  @moduledoc "Create / edit an inventory location (name + description)."
  use FleetmsWeb, :live_view

  alias AshPhoenix.Form
  alias Fleetms.Inventory

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, active_link: :inventory)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    scope = socket.assigns.current_scope

    form =
      Form.for_create(Inventory.InventoryLocation, :create,
        domain: Inventory,
        as: "location",
        actor: scope.user,
        tenant: scope.organization
      )

    socket
    |> assign(page_title: gettext("New location"))
    |> assign(:form, to_form(form))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    scope = socket.assigns.current_scope

    case Inventory.get_inventory_location(id, scope: scope) do
      {:ok, location} ->
        form =
          Form.for_update(location, :update,
            domain: Inventory,
            as: "location",
            actor: scope.user,
            tenant: scope.organization
          )

        socket
        |> assign(page_title: gettext("Edit location"))
        |> assign(:form, to_form(form))

      {:error, _} ->
        socket
        |> put_flash(:error, gettext("That location could not be found."))
        |> push_navigate(to: ~p"/o/#{org(socket)}/inventory-locations")
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
        %{label: gettext("Inventory Locations"), path: ~p"/o/#{org(assigns)}/inventory-locations"},
        %{label: @page_title}
      ]} />

      <.header>{@page_title}</.header>

      <.form
        :let={f}
        for={@form}
        id="location-form"
        phx-change="validate"
        phx-submit="save"
        class="mt-6"
      >
        <div class="rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800">
          <.input field={f[:name]} type="text" label={gettext("Name")} required />
          <.input field={f[:description]} type="textarea" label={gettext("Description")} />
        </div>

        <div class="mt-6 flex items-center gap-3">
          <.button type="submit" phx-disable-with={gettext("Saving…")}>
            {gettext("Save location")}
          </.button>
          <.button variant="secondary" navigate={~p"/o/#{org(assigns)}/inventory-locations"}>
            {gettext("Cancel")}
          </.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"location" => params}, socket) do
    {:noreply, assign(socket, :form, Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"location" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, _location} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Location saved."))
         |> push_navigate(to: ~p"/o/#{org(socket)}/inventory-locations")}

      {:error, form} ->
        {:noreply,
         socket
         |> assign(:form, form)
         |> put_flash(:error, gettext("Please fix the errors below."))}
    end
  end

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
