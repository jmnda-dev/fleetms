defmodule FleetmsWeb.InspectionFormLive.Detail do
  use FleetmsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :show, false) |> assign(:active_link, :inspection_forms)}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _, socket) do
    %{tenant: tenant, current_user: actor, live_action: live_action} = socket.assigns

    inspection_form =
      Ash.get!(Fleetms.Inspection.InspectionForm, id, tenant: tenant, actor: actor)
      |> Ash.load!(
        [
          :radio_inputs,
          :dropdown_inputs,
          :number_inputs,
          :signature_inputs
        ],
        tenant: tenant,
        actor: actor
      )

    form =
      inspection_form
      |> AshPhoenix.Form.for_action(:update,
        as: "inspection_form",
        domain: Fleetms.Inspection,
        actor: actor,
        tenant: tenant,
        forms: [
          radio_inputs: [
            type: :list,
            resource: Fleetms.Inspection.Form.RadioInput,
            data: inspection_form.radio_inputs,
            create_action: :create,
            update_action: :update
          ],
          dropdown_inputs: [
            type: :list,
            resource: Fleetms.Inspection.Form.DropdownInput,
            data: inspection_form.dropdown_inputs,
            create_action: :create,
            update_action: :update,
            forms: [
              options: [
                type: :list,
                as: "options",
                resource: Fleetms.Inspection.Form.InputChoice,
                data: & &1.options,
                create_action: :create,
                update_action: :update
              ]
            ]
          ],
          number_inputs: [
            type: :list,
            resource: Fleetms.Inspection.Form.NumberInput,
            data: inspection_form.number_inputs,
            create_action: :create,
            update_action: :update
          ],
          signature_inputs: [
            type: :list,
            resource: Fleetms.Inspection.Form.SignatureInput,
            data: inspection_form.signature_inputs,
            create_action: :create,
            update_action: :update
          ]
        ]
      )

    socket =
      socket
      |> assign(:page_title, page_title(live_action))
      |> assign(
        :inspection_form,
        inspection_form
      )
      |> assign(:form, form |> to_form())

    {:noreply, apply_action(socket, live_action, params)}
  end

  @impl true
  def handle_event("validate", %{"inspection_form" => inspection_form_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, inspection_form_params)

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("add_form", %{"path" => path}, socket) do
    form = AshPhoenix.Form.add_form(socket.assigns.form, path)
    socket = assign(socket, :form, form)
    {:noreply, push_event(socket, "initFlowbiteJS", %{})}
  end

  @impl true
  def handle_event("remove_form", %{"path" => path}, socket) do
    form = AshPhoenix.Form.remove_form(socket.assigns.form, path)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("show", _params, socket) do
    # form = AshPhoenix.Form.remove_form(socket.assigns.form, path)
    {:noreply, assign(socket, :show, true)}
  end

  @impl true
  def handle_event("save", %{"inspection_form" => inspection_form_params}, socket) do
    can_perform_action? =
      Ash.can?(
        {Fleetms.Inspection.InspectionForm, :update},
        socket.assigns.current_user
      )

    if can_perform_action? do
      case AshPhoenix.Form.submit(socket.assigns.form, params: inspection_form_params) do
        {:ok, inspection_form} ->
          {:noreply,
           socket
           |> put_flash(:info, "Inspection Form updated successfully")
           |> push_patch(to: ~p"/inspection_forms/#{inspection_form}")}

        {:error, form} ->
          case AshPhoenix.Form.errors(form, format: :simple) do
            [name: "has already been taken"] ->
              socket =
                put_flash(
                  socket,
                  :error,
                  "An error occured. Ensure there are no fields with the same name."
                )
                |> assign(:form, form)

              {:noreply, socket}

            _errors ->
              {:noreply, assign(socket, :form, form)}
          end
      end
    else
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :detail, _params), do: socket

  defp page_title(:detail), do: "Show Inspection Form"
  defp page_title(:edit), do: "Edit Inspection Form"
end
