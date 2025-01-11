defmodule FleetmsWeb.InspectionFormLive.Index do
  use FleetmsWeb, :live_view
  alias FleetmsWeb.LiveUserAuth

  on_mount {LiveUserAuth, :inspections_module}

  @impl true
  def mount(_params, _session, socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns
    inspection_forms = list_inspection_forms(tenant, actor)

    socket =
      stream(socket, :inspection_forms, inspection_forms.results)
      |> assign(:active_link, :inspection_forms)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("validate", %{"inspection_form" => inspection_form_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, inspection_form_params)

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"inspection_form" => inspection_form_params}, socket) do
    save_inspection_form(socket, socket.assigns.live_action, inspection_form_params)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    can_perform_action? =
      Ash.can?(
        {Fleetms.VehicleInspection.InspectionForm, :destroy},
        actor
      )

    if can_perform_action? do
      inspection_form =
        Fleetms.VehicleInspection.InspectionForm.get_by_id!(id, tenant: tenant, actor: actor)

      Ash.destroy!(inspection_form, tenant: tenant, actor: actor)

      socket =
        socket
        |> stream_delete(:inspection_forms, inspection_form)
        |> put_toast(:info, "#{inspection_form.title} was deleted successfully")

      {:noreply, socket}
    else
      raise FleetmsWeb.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"

      {:noreply, socket}
    end
  end

  defp save_inspection_form(socket, :new, inspection_form_params) do
    can_perform_action? =
      Ash.can?(
        {Fleetms.VehicleInspection.InspectionForm, :create},
        socket.assigns.current_user
      )

    if can_perform_action? do
      case AshPhoenix.Form.submit(socket.assigns.form, params: inspection_form_params) do
        {:ok, inspection_form} ->
          stream_insert(socket, :inspection_forms, inspection_form)

          {:noreply,
           stream_insert(socket, :inspection_forms, inspection_form)
           |> put_toast(:info, "Inspection Form created successfully")
           |> push_patch(to: ~p"/inspection_forms")}

        {:error, form} ->
          {:noreply, assign(socket, :form, form)}
      end
    else
      raise FleetmsWeb.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    can_perform_action? =
      Ash.can?(
        {Fleetms.VehicleInspection.InspectionForm, :update},
        actor
      )

    if can_perform_action? do
      inspection_form =
        Fleetms.VehicleInspection.InspectionForm.get_by_id!(id, tenant: tenant, actor: actor)

      form =
        inspection_form
        |> AshPhoenix.Form.for_update(:update,
          as: "inspection_form",
          domain: Fleetms.VehicleInspection,
          forms: [auto?: true],
          actor: actor,
          tenant: tenant
        )
        |> to_form()

      socket
      |> assign(:page_title, "Edit Inspection Form")
      |> assign(:form, form)
    else
      raise FleetmsWeb.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :new, _params) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    can_perform_action? =
      Ash.can?(
        {Fleetms.VehicleInspection.InspectionForm, :create},
        actor
      )

    if can_perform_action? do
      form =
        Fleetms.VehicleInspection.InspectionForm
        |> AshPhoenix.Form.for_create(:create,
          as: "inspection_form",
          domain: Fleetms.VehicleInspection,
          forms: [auto?: true],
          actor: actor,
          tenant: tenant
        )
        |> to_form()

      socket
      |> assign(:page_title, "New Inspection Form")
      |> assign(:form, form)
    else
      raise FleetmsWeb.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Inspection Forms")
    |> assign(:inspection_form, nil)
  end

  defp list_inspection_forms(tenant, actor) do
    Fleetms.VehicleInspection.InspectionForm
    |> Ash.Query.for_read(:list)
    |> Ash.read!(tenant: tenant, actor: actor)
  end
end
