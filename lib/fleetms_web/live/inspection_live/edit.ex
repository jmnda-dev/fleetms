defmodule FleetmsWeb.InspectionLive.Edit do
  use FleetmsWeb, :live_view

  alias Fleetms.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :active_link, :inspection_submissions)}
  end

  @impl true
  def handle_params(%{"id" => id} = _params, _uri, socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    inspection =
      Fleetms.VehicleInspection.InspectionSubmission.get_by_id!(id, tenant: tenant, actor: actor)

    can_perform_action? =
      Ash.can?(
        {inspection, :update},
        actor
      )

    if can_perform_action? do
      users =
        Accounts.get_all_users!(tenant: tenant, actor: actor)
        |> Enum.map(&{&1.user_profile.full_name, &1.id})

      vehicles =
        Fleetms.VehicleManagement.Vehicle.get_all!(tenant: tenant, actor: actor)
        |> Enum.map(&{&1.name, &1.id})

      inspection_forms =
        Fleetms.VehicleInspection.InspectionForm.get_all!(tenant: tenant, actor: actor)
        |> Enum.map(&{&1.title, &1.id})

      form =
        inspection
        |> AshPhoenix.Form.for_update(:update,
          as: "inspection_submission",
          domain: Fleetms.VehicleInspection,
          actor: socket.assigns.current_user,
          tenant: tenant,
          forms: [
            radio_input_values: [
              type: :list,
              resource: Fleetms.VehicleInspection.RadioInputValue,
              data: inspection.radio_input_values,
              update_action: :update
            ],
            dropdown_input_values: [
              type: :list,
              resource: Fleetms.VehicleInspection.DropdownInputValue,
              data: inspection.dropdown_input_values,
              update_action: :update
            ],
            number_input_values: [
              type: :list,
              resource: Fleetms.VehicleInspection.NumberInputValue,
              data: inspection.number_input_values,
              update_action: :update
            ],
            signature_input_values: [
              type: :list,
              resource: Fleetms.VehicleInspection.SignatureInputValue,
              data: inspection.signature_input_values,
              update_action: :update
            ]
          ]
        )

      socket =
        socket
        |> assign(:vehicles, vehicles)
        |> assign(:inspection_forms, inspection_forms)
        |> assign(:form, form |> to_form())
        |> assign(:inspection, inspection)
        |> assign(:users, users)

      {:noreply, socket}
    else
      raise FleetmsWeb.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  @impl true
  def handle_event("validate", %{"inspection_submission" => inspection_submission_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, inspection_submission_params)

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"inspection_submission" => inspection_submission_params}, socket) do
    params =
      inspection_submission_params
      |> Map.put("inspection_form_id", socket.assigns.inspection.inspection_form_id)

    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, inspection} ->
        {:noreply,
         socket
         |> put_toast(:info, "Inspection was saved successfully")
         |> push_navigate(to: ~p"/inspections/#{inspection}")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def maybe_show_comment_form(form, opts \\ []) do
    status = get_form_value(form, :status)
    comment_required_on_pass = get_form_value(form, :comment_required_on_pass)
    comment_required_on_fail = get_form_value(form, :comment_required_on_fail)

    cond do
      comment_required_on_pass and comment_required_on_fail ->
        true

      status == :Pass and comment_required_on_pass ->
        true

      status == :Fail and comment_required_on_fail ->
        true

      is_nil(status) and opts[:hide_if_nil] ->
        false

      true ->
        false
    end
  end
end
