defmodule FleetmsWeb.VendorLive.Form do
  @moduledoc "Create / edit a vendor (name + contact details)."
  use FleetmsWeb, :live_view

  alias AshPhoenix.Form
  alias Fleetms.Maintenance

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, active_link: :maintenance)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    scope = socket.assigns.current_scope

    form =
      Form.for_create(Maintenance.Vendor, :create,
        domain: Maintenance,
        as: "vendor",
        actor: scope.user,
        tenant: scope.organization
      )

    socket
    |> assign(page_title: gettext("New vendor"))
    |> assign(:form, to_form(form))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    scope = socket.assigns.current_scope

    case Maintenance.get_vendor(id, scope: scope) do
      {:ok, vendor} ->
        form =
          Form.for_update(vendor, :update,
            domain: Maintenance,
            as: "vendor",
            actor: scope.user,
            tenant: scope.organization
          )

        socket
        |> assign(page_title: gettext("Edit vendor"))
        |> assign(:form, to_form(form))

      {:error, _} ->
        socket
        |> put_flash(:error, gettext("That vendor could not be found."))
        |> push_navigate(to: ~p"/o/#{org(socket)}/vendors")
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
        %{label: gettext("Vendors"), path: ~p"/o/#{org(assigns)}/vendors"},
        %{label: @page_title}
      ]} />

      <.header>{@page_title}</.header>

      <.form
        :let={f}
        for={@form}
        id="vendor-form"
        phx-change="validate"
        phx-submit="save"
        class="mt-6"
      >
        <div class="rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800">
          <div class="grid gap-4 md:grid-cols-2">
            <.input field={f[:name]} type="text" label={gettext("Name")} required />
            <.input field={f[:contact_name]} type="text" label={gettext("Contact name")} />
            <.input field={f[:email]} type="text" label={gettext("Email")} />
            <.input field={f[:phone]} type="text" label={gettext("Phone")} />
            <.input field={f[:website]} type="text" label={gettext("Website")} />
            <div class="md:col-span-2">
              <.input field={f[:address]} type="textarea" label={gettext("Address")} />
            </div>
            <div class="md:col-span-2">
              <.input field={f[:notes]} type="textarea" label={gettext("Notes")} />
            </div>
          </div>
        </div>

        <div class="mt-6 flex items-center gap-3">
          <.button type="submit" phx-disable-with={gettext("Saving…")}>
            {gettext("Save vendor")}
          </.button>
          <.button variant="secondary" navigate={~p"/o/#{org(assigns)}/vendors"}>
            {gettext("Cancel")}
          </.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"vendor" => params}, socket) do
    {:noreply, assign(socket, :form, Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"vendor" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, _vendor} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Vendor saved."))
         |> push_navigate(to: ~p"/o/#{org(socket)}/vendors")}

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
