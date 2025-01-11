defmodule FleetmsWeb.IssueLive.Detail do
  use FleetmsWeb, :live_view

  alias FleetmsWeb.LiveUserAuth

  on_mount {LiveUserAuth, :issues_module}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :active_link, :issues)}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    %{tenant: tenant, current_user: actor, live_action: live_action} = socket.assigns

    {:noreply,
     socket
     |> assign(:page_title, page_title(live_action))
     |> assign(
       :issue,
       Fleetms.VehicleIssues.Issue.get_by_id!(id, tenant: tenant, actor: actor)
     )}
  end

  @impl true
  def handle_event("reopen_issue", _params, socket) do
    %{issue: issue, tenant: tenant, current_user: actor} = socket.assigns

    updated_issue =
      issue
      |> Ash.Changeset.for_update(:reopen_issue)
      |> Ash.update!(tenant: tenant, actor: actor)

    socket =
      assign(socket, :issue, updated_issue)
      |> put_toast(:info, "Issue ##{updated_issue.issue_number} was reopened!")

    {:noreply, socket}
  end

  defp page_title(:detail), do: "Issue Details"
  defp page_title(:edit), do: "Edit Issue"
  defp page_title(:resolve_issue_with_comment), do: "Resolve Issue with Comment"
  defp page_title(:close_issue), do: "Close Issue"
end
