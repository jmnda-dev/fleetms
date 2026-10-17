defmodule FleetmsWeb.ServiceTaskLive.Form do
  @moduledoc "Create / edit a service task (name + description)."
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
      Form.for_create(Maintenance.ServiceTask, :create,
        domain: Maintenance,
        as: "service_task",
        actor: scope.user,
        tenant: scope.organization
      )

    socket
    |> assign(page_title: gettext("New service task"))
    |> assign(:form, to_form(form))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    scope = socket.assigns.current_scope

    case Maintenance.get_service_task(id, scope: scope) do
      {:ok, task} ->
        form =
          Form.for_update(task, :update,
            domain: Maintenance,
            as: "service_task",
            actor: scope.user,
            tenant: scope.organization
          )

        socket
        |> assign(page_title: gettext("Edit service task"))
        |> assign(:form, to_form(form))

      {:error, _} ->
        socket
        |> put_flash(:error, gettext("That service task could not be found."))
        |> push_navigate(to: ~p"/o/#{org(socket)}/service-tasks")
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
        %{label: gettext("Service Tasks"), path: ~p"/o/#{org(assigns)}/service-tasks"},
        %{label: @page_title}
      ]} />

      <.header>{@page_title}</.header>

      <.form
        :let={f}
        for={@form}
        id="service-task-form"
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
            {gettext("Save service task")}
          </.button>
          <.button variant="secondary" navigate={~p"/o/#{org(assigns)}/service-tasks"}>
            {gettext("Cancel")}
          </.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"service_task" => params}, socket) do
    {:noreply, assign(socket, :form, Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"service_task" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, _task} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Service task saved."))
         |> push_navigate(to: ~p"/o/#{org(socket)}/service-tasks")}

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
