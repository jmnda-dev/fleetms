defmodule FleetmsWeb.IssueLive.Form do
  @moduledoc """
  Report (create) / edit an issue.

  A straightforward `AshPhoenix.Form` over the issue's create/update action. The
  vehicle and assignee are searchable selects bound directly to the writable
  `vehicle_id` / `assigned_to_id` attributes. Tags use a multi, creatable select
  bound to the action's `tags` argument: typing a name relates an existing tag or
  creates it (see the issue's `manage_relationship(:tags, ...)`).
  """
  use FleetmsWeb, :live_view

  alias AshPhoenix.Form
  alias Fleetms.Accounts
  alias Fleetms.Format
  alias Fleetms.Tagging
  alias Fleetms.VehicleIssues
  alias Fleetms.VehicleManagement

  # Shown in the org's distance unit, stored canonically in km.
  @unit_fields %{"mileage" => :distance}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, active_link: :issues)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, params) do
    scope = socket.assigns.current_scope

    form =
      Form.for_create(VehicleIssues.Issue, :create,
        domain: VehicleIssues,
        as: "issue",
        scope: scope
      )

    socket
    |> assign(page_title: gettext("Report issue"), issue: nil, tags_value: [])
    |> assign(preselect_vehicle: params["vehicle_id"])
    |> assign_lookups(scope)
    |> assign(:form, to_form(form))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    scope = socket.assigns.current_scope

    case VehicleIssues.get_issue(id, scope: scope, load: [:tags]) do
      {:ok, issue} ->
        form =
          Form.for_update(issue, :update,
            domain: VehicleIssues,
            as: "issue",
            scope: scope
          )

        socket
        |> assign(
          page_title: gettext("Edit issue #%{n}", n: issue.issue_number),
          issue: issue,
          tags_value: Enum.map(issue.tags, &to_string(&1.name)),
          preselect_vehicle: nil
        )
        |> assign_lookups(scope)
        |> assign(:form, to_form(form))

      {:error, _} ->
        socket
        |> put_flash(:error, gettext("That issue could not be found."))
        |> push_navigate(to: ~p"/o/#{org(socket)}/issues")
    end
  end

  defp assign_lookups(socket, scope) do
    assign(socket,
      vehicles: vehicle_options(scope),
      members: member_options(scope),
      tag_options: tag_options(scope)
    )
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
        %{label: gettext("Issues"), path: ~p"/o/#{org(assigns)}/issues"},
        %{label: @page_title}
      ]} />

      <.header>
        {@page_title}
        <:subtitle>{gettext("Describe the fault, who it concerns and how urgent it is.")}</:subtitle>
      </.header>

      <.form :let={f} for={@form} id="issue-form" phx-change="validate" phx-submit="save" class="mt-6">
        <div class="rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800">
          <div class="grid gap-4 md:grid-cols-2">
            <div class="md:col-span-2">
              <.input field={f[:title]} label={gettext("Title")} required />
            </div>

            <.search_select
              field={f[:vehicle_id]}
              value={f[:vehicle_id].value || @preselect_vehicle}
              label={gettext("Vehicle")}
              prompt={gettext("Select a vehicle")}
              options={@vehicles}
            />
            <.search_select
              field={f[:assigned_to_id]}
              label={gettext("Assignee")}
              prompt={gettext("Unassigned")}
              options={@members}
            />

            <.search_select
              field={f[:priority]}
              label={gettext("Priority")}
              prompt={gettext("Select a priority")}
              options={priority_options()}
            />
            <.date_input field={f[:due_date]} label={gettext("Due date")} />

            <.input
              field={f[:mileage]}
              value={Format.distance_input(f[:mileage].value, org(assigns))}
              type="number"
              step="0.01"
              label={"#{gettext("Mileage at report")} (#{Format.distance_unit(org(assigns))})"}
            />
            <.input
              field={f[:hours]}
              type="number"
              step="0.01"
              label={gettext("Engine hours at report")}
            />

            <div class="md:col-span-2">
              <.search_select
                field={f[:tags]}
                value={@tags_value}
                multiple
                create
                options={@tag_options}
                label={gettext("Tags")}
                prompt={gettext("Add tags…")}
              />
            </div>

            <div class="md:col-span-2">
              <.rich_text field={f[:description]} label={gettext("Description")} />
            </div>
          </div>
        </div>

        <div class="mt-6 flex items-center gap-3">
          <.button type="submit" phx-disable-with={gettext("Saving…")}>
            {gettext("Save issue")}
          </.button>
          <.button variant="secondary" navigate={~p"/o/#{org(assigns)}/issues"}>
            {gettext("Cancel")}
          </.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"issue" => params}, socket) do
    {:noreply, assign(socket, :form, Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"issue" => params}, socket) do
    params = Format.to_canonical_params(params, @unit_fields, org(socket))

    case Form.submit(socket.assigns.form, params: params) do
      {:ok, issue} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Issue saved."))
         |> push_navigate(to: ~p"/o/#{org(socket)}/issues/#{issue.id}")}

      {:error, form} ->
        {:noreply,
         socket
         |> assign(:form, form)
         |> put_flash(:error, gettext("Please fix the errors below."))}
    end
  end

  # --- lookups ---

  defp vehicle_options(scope) do
    case VehicleManagement.list_selectable_vehicles(scope: scope) do
      {:ok, vehicles} -> Enum.map(vehicles, &{&1.name, &1.id})
      _ -> []
    end
  end

  defp member_options(scope) do
    Accounts.list_user_organizations!(
      scope: scope,
      query: [filter: [organization_id: scope.organization.id, status: :active]],
      load: [user: [:email, profile: [:first_name, :last_name]]]
    )
    |> Enum.map(fn membership ->
      {member_label(membership.user), membership.user_id}
    end)
  end

  # Build a display name from the loaded profile, falling back to the email.
  defp member_label(%{profile: %{first_name: first, last_name: last}} = user) do
    case [first, last] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" ") do
      "" -> to_string(user.email)
      name -> name
    end
  end

  defp member_label(%{email: email}), do: to_string(email)

  # Existing tag names for autocomplete; the value is the name so every submitted entry
  # (picked or freshly typed) is a name the action can relate-or-create.
  defp tag_options(scope) do
    Tagging.list_tags!(scope: scope)
    |> Enum.map(&{to_string(&1.name), to_string(&1.name)})
  end

  defp priority_options, do: Enum.map(VehicleIssues.IssuePriority.values(), &{to_string(&1), &1})

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
