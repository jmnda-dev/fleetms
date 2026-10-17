defmodule FleetmsWeb.ContactLive.Form do
  @moduledoc "Create / edit a contact — an `AshPhoenix.Form` over the contact actions."
  use FleetmsWeb, :live_view

  alias AshPhoenix.Form
  alias Fleetms.Contacts
  alias Fleetms.Contacts.Contact
  alias Fleetms.Contacts.ContactType

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, active_link: :contacts)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    scope = socket.assigns.current_scope
    form = Form.for_create(Contact, :create, domain: Contacts, as: "contact", scope: scope)

    socket
    |> assign(page_title: gettext("New contact"))
    |> assign(:form, to_form(form))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    scope = socket.assigns.current_scope

    case Contacts.get_contact(id, scope: scope) do
      {:ok, contact} ->
        form = Form.for_update(contact, :update, domain: Contacts, as: "contact", scope: scope)

        socket
        |> assign(page_title: gettext("Edit contact"))
        |> assign(:form, to_form(form))

      {:error, _} ->
        socket
        |> put_flash(:error, gettext("That contact could not be found."))
        |> push_navigate(to: ~p"/o/#{org(socket)}/contacts")
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
        %{label: gettext("Contacts"), path: ~p"/o/#{org(assigns)}/contacts"},
        %{label: @page_title}
      ]} />

      <.header>
        {@page_title}
        <:subtitle>
          {gettext("An external party you deal with — vendor, insurer, inspector.")}
        </:subtitle>
      </.header>

      <.form
        :let={f}
        for={@form}
        id="contact-form"
        phx-change="validate"
        phx-submit="save"
        class="mt-6"
      >
        <div class="rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800">
          <div class="grid gap-4 md:grid-cols-2">
            <.input field={f[:name]} label={gettext("Name")} required />
            <.input
              field={f[:contact_type]}
              type="select"
              label={gettext("Type")}
              options={type_options()}
            />

            <.input field={f[:company]} label={gettext("Company")} />
            <.input field={f[:title]} label={gettext("Title / role")} />

            <.input field={f[:phone]} label={gettext("Phone")} />
            <.input field={f[:email]} type="email" label={gettext("Email")} />

            <div class="md:col-span-2">
              <.input field={f[:notes]} type="textarea" label={gettext("Notes")} />
            </div>
          </div>
        </div>

        <div class="mt-6 flex items-center gap-3">
          <.button type="submit" phx-disable-with={gettext("Saving…")}>
            {gettext("Save contact")}
          </.button>
          <.button variant="secondary" navigate={~p"/o/#{org(assigns)}/contacts"}>
            {gettext("Cancel")}
          </.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"contact" => params}, socket) do
    {:noreply, assign(socket, :form, Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"contact" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, _contact} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Contact saved."))
         |> push_navigate(to: ~p"/o/#{org(socket)}/contacts")}

      {:error, form} ->
        {:noreply,
         socket
         |> assign(:form, form)
         |> put_flash(:error, gettext("Please fix the errors below."))}
    end
  end

  defp type_options do
    Enum.map(ContactType.values(), &{&1 |> to_string() |> String.capitalize(), &1})
  end

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
