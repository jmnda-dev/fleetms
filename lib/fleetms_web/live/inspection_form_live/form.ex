defmodule FleetmsWeb.InspectionFormLive.Form do
  @moduledoc "Create a new inspection form (title + description); saving opens the builder."
  use FleetmsWeb, :live_view

  alias AshPhoenix.Form
  alias Fleetms.Inspections

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, active_link: :inspections)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    scope = socket.assigns.current_scope

    form =
      Form.for_create(Inspections.InspectionForm, :create,
        domain: Inspections,
        as: "inspection_form",
        actor: scope.user,
        tenant: scope.organization
      )

    {:noreply,
     socket
     |> assign(page_title: gettext("New inspection form"))
     |> assign(:form, to_form(form))}
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
        %{label: gettext("Inspection Forms"), path: ~p"/o/#{org(assigns)}/inspection-forms"},
        %{label: @page_title}
      ]} />

      <.header>{@page_title}</.header>

      <.form
        :let={f}
        for={@form}
        id="inspection-form-form"
        phx-change="validate"
        phx-submit="save"
        class="mt-6"
      >
        <div class="rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800">
          <div class="grid gap-4">
            <.input field={f[:title]} type="text" label={gettext("Title")} required />
            <.input
              field={f[:description]}
              type="textarea"
              label={gettext("Description")}
              help={gettext("Optional. Shown to whoever fills the inspection.")}
            />
          </div>
        </div>

        <div class="mt-6 flex items-center gap-3">
          <.button type="submit" phx-disable-with={gettext("Creating…")}>
            {gettext("Create and open builder")}
          </.button>
          <.button variant="secondary" navigate={~p"/o/#{org(assigns)}/inspection-forms"}>
            {gettext("Cancel")}
          </.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"inspection_form" => params}, socket) do
    {:noreply, assign(socket, :form, Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"inspection_form" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, form} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Form created — start adding sections."))
         |> push_navigate(to: ~p"/o/#{org(socket)}/inspection-forms/#{form.id}/build")}

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
