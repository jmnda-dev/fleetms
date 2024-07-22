defmodule FleetmsWeb.InspectionLive.List do
  use FleetmsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :active_link, :inspection_submissions)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    %{tenant: tenant, current_user: actor, live_action: live_action} = socket.assigns
    inspection_submissions = list_inspection_submissions(tenant, actor)

    socket =
      socket
      |> stream(:inspection_submissions, inspection_submissions.results)

    {:noreply, apply_action(socket, live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Inspection Submissions")
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    can_perform_action? =
      Ash.can?(
        {Fleetms.Inspection.InspectionSubmission, :destroy},
        socket.assigns.current_user
      )

    if can_perform_action? do
      inspection = Fleetms.Inspection.InspectionSubmission.for_delete!(id)

      Ash.destroy!(inspection, actor: actor, tenant: tenant)

      socket =
        socket
        |> stream_delete(:inspection_submissions, inspection)
        |> put_flash(:info, "Inspection Submission was deleted successfully")

      {:noreply, socket}
    else
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"

      {:noreply, socket}
    end
  end

  defp list_inspection_submissions(tenant, actor) do
    Fleetms.Inspection.InspectionSubmission
    |> Ash.Query.for_read(:list)
    |> Ash.read!(tenant: tenant, actor: actor)
  end
end
