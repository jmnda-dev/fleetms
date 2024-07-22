defmodule FleetmsWeb.InspectionLive.New do
  use FleetmsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    can_perform_action? =
      Ash.can?(
        {Fleetms.Inspection.InspectionSubmission, :create},
        socket.assigns.current_user
      )

    if can_perform_action? do
      {:ok, assign(socket, :active_link, :inspection_submissions)}
    else
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    vehicles =
      Fleetms.Vehicles.Vehicle.get_all!(tenant: tenant, actor: actor)
      |> Enum.map(&{&1.name, &1.id})

    inspection_forms =
      Fleetms.Inspection.InspectionForm.get_all!(tenant: tenant, actor: actor)
      |> Enum.map(&{&1.title, &1.id})

    form =
      Fleetms.Inspection.InspectionSubmission
      |> AshPhoenix.Form.for_create(:create,
        as: "inspection_submission",
        domain: Fleetms.Inspection,
        actor: socket.assigns.current_user,
        tenant: tenant,
        forms: [
          radio_input_values: [
            type: :list,
            resource: Fleetms.Inspection.RadioInputValue,
            create_action: :create
          ],
          dropdown_input_values: [
            type: :list,
            resource: Fleetms.Inspection.DropdownInputValue,
            create_action: :create
          ],
          number_input_values: [
            type: :list,
            resource: Fleetms.Inspection.NumberInputValue,
            create_action: :create
          ],
          signature_input_values: [
            type: :list,
            resource: Fleetms.Inspection.SignatureInputValue,
            create_action: :create
          ]
        ]
      )

    socket =
      socket
      |> assign(:vehicles, vehicles)
      |> assign(:inspection_forms, inspection_forms)
      |> assign(:form, form |> to_form())

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"inspection_submission" => inspection_submission_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, inspection_submission_params)

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"inspection_submission" => inspection_submission_params}, socket) do
    user = socket.assigns.current_user
    inspection_submission_params = Map.put(inspection_submission_params, "user_id", user.id)

    case AshPhoenix.Form.submit(socket.assigns.form, params: inspection_submission_params) do
      {:ok, _inspection_form} ->
        {:noreply,
         socket
         |> put_flash(:info, "Inspection was saved successfully")
         |> push_navigate(to: ~p"/inspections")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  @impl true
  def handle_event(
        "inspection_form_selected",
        %{"inspection_submission" => %{"inspection_form_id" => id} = params},
        socket
      ) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    inspection_form =
      Fleetms.Inspection.InspectionForm.get_by_id!(id, tenant: tenant, actor: actor)

    form =
      AshPhoenix.Form.validate(socket.assigns.form, params)
      |> add_pass_fail_forms(inspection_form.radio_inputs)
      |> add_dropdown_input_forms(inspection_form.dropdown_inputs)
      |> add_number_input_forms(inspection_form.number_inputs)
      |> add_signature_input_forms(inspection_form.signature_inputs)

    {:noreply, assign(socket, :form, form)}
  end

  defp add_pass_fail_forms(form, radio_input_resources) do
    if radio_input_resources == [] do
      form
    else
      Enum.reduce(radio_input_resources, form, fn radio_input_resource, form ->
        AshPhoenix.Form.add_form(
          form,
          "inspection_submission[radio_input_values]",
          params: build_attrs(radio_input_resource, :radio_input)
        )
      end)
    end
  end

  defp add_dropdown_input_forms(form, dropdown_input_resources) do
    if dropdown_input_resources == [] do
      form
    else
      Enum.reduce(dropdown_input_resources, form, fn dropdown_input_resource, form ->
        AshPhoenix.Form.add_form(
          form,
          "inspection_submission[dropdown_input_values]",
          params: build_attrs(dropdown_input_resource, :dropdown_input)
        )
      end)
    end
  end

  def add_number_input_forms(form, number_input_resources) do
    if number_input_resources == [] do
      form
    else
      Enum.reduce(number_input_resources, form, fn number_input_resource, form ->
        AshPhoenix.Form.add_form(
          form,
          "inspection_submission[number_input_values]",
          params: build_attrs(number_input_resource, :number_input)
        )
      end)
    end
  end

  def add_signature_input_forms(form, signature_input_resources) do
    if signature_input_resources == [] do
      form
    else
      Enum.reduce(signature_input_resources, form, fn signature_input_resource, form ->
        AshPhoenix.Form.add_form(
          form,
          "inspection_submission[signature_input_values]",
          params: build_attrs(signature_input_resource, :signature_input)
        )
      end)
    end
  end

  defp build_attrs(resource, :radio_input) do
    %{
      name: resource.name,
      slug: resource.slug,
      help_text: resource.help_text,
      pass_label: resource.pass_label,
      fail_label: resource.fail_label,
      allow_na: resource.allow_na,
      comment_required_on_pass: resource.comment_required_on_pass,
      comment_required_on_fail: resource.comment_required_on_fail
    }
  end

  defp build_attrs(resource, :dropdown_input) do
    %{
      name: resource.name,
      slug: resource.slug,
      help_text: resource.help_text,
      fail_options: get_fail_options(resource),
      options: Enum.map(resource.options, & &1.label),
      comment_required_on_pass: resource.comment_required_on_pass,
      comment_required_on_fail: resource.comment_required_on_fail
    }
  end

  defp build_attrs(resource, :number_input) do
    %{
      name: resource.name,
      slug: resource.slug,
      help_text: resource.help_text,
      pass_range_min: resource.pass_range_min,
      pass_range_max: resource.pass_range_max,
      comment_required_on_pass: resource.comment_required_on_pass,
      comment_required_on_fail: resource.comment_required_on_fail
    }
  end

  defp build_attrs(resource, :signature_input) do
    %{
      label: resource.name,
      help_text: resource.help_text,
      required: resource.required
    }
  end

  defp get_fail_options(resource) do
    Stream.filter(resource.options, & &1.fail_if_selected)
    |> Enum.map(& &1.label)
  end

  defp get_dropdown_options(form) do
    get_form_value(form, :options) || form.params["options"]
  end

  defp get_dropdown_fail_options(form) do
    get_form_value(form, :fail_options) || form.params["fail_options"]
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
