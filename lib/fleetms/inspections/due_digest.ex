defmodule Fleetms.Inspections.DueDigest do
  @moduledoc """
  Builds and sends the daily "inspections due" email digest for one organization.

  Called per tenant by the `InspectionAssignment.send_due_digest` scheduled action
  (which AshOban runs once per organization). It gathers the org's open assignments
  that are overdue or due within the next week and emails a summary to the
  organization's owner(s). It is purely a notifier — an assignment's `status` is
  already correct on its own; this just tells someone about it. Runs unauthorized
  (a system job, no actor).
  """
  require Ash.Query

  import Swoosh.Email

  alias Fleetms.{Accounts, Emails, Mailer}
  alias Fleetms.Inspections.InspectionAssignment

  # How far ahead of the due date an open assignment starts appearing in the digest.
  @horizon_days 7

  @doc """
  Sends the digest for the given tenant (an `org_<id>` schema string). Returns
  `{:ok, count}` where `count` is how many recipients were emailed (0 if nothing is
  due or the org has no reachable owner).
  """
  @spec deliver_for_tenant(String.t()) :: {:ok, non_neg_integer()}
  def deliver_for_tenant(tenant) do
    case due_assignments(tenant) do
      [] ->
        {:ok, 0}

      assignments ->
        org_id = org_id_from_tenant(tenant)
        recipients = owner_emails(org_id)

        if recipients == [] do
          {:ok, 0}
        else
          org = Accounts.get_organization!(org_id, authorize?: false)
          deliver(recipients, org, assignments)
          {:ok, length(recipients)}
        end
    end
  end

  defp due_assignments(tenant) do
    horizon = Date.add(Date.utc_today(), @horizon_days)

    InspectionAssignment
    |> Ash.Query.filter(is_nil(completed_at) and due_on <= ^horizon)
    |> Ash.Query.load([
      :status,
      vehicle: [:name],
      inspection_form: [:title],
      assigned_to: [profile: [:first_name, :last_name]]
    ])
    |> Ash.Query.sort(due_on: :asc)
    |> Ash.read!(tenant: tenant, authorize?: false)
  end

  defp owner_emails(org_id) do
    Accounts.list_user_organizations!(
      query: [filter: [organization_id: org_id, owner?: true]],
      load: [user: [:email]],
      authorize?: false
    )
    |> Enum.map(&to_string(&1.user.email))
    |> Enum.reject(&(&1 == ""))
  end

  defp org_id_from_tenant("org_" <> id), do: id
  defp org_id_from_tenant(tenant), do: tenant

  defp deliver(recipients, org, assignments) do
    new()
    |> from({"FleetMS", "noreply@fleetms.app"})
    |> to(recipients)
    |> subject("#{length(assignments)} inspection(s) due — #{org.name}")
    |> html_body(body(org, assignments))
    |> Mailer.deliver!()
  end

  defp body(org, assignments) do
    rows =
      Enum.map_join(assignments, "", fn assignment ->
        """
        <tr>
          <td>#{Emails.escape(assignment.vehicle.name)}</td>
          <td>#{Emails.escape(assignment.inspection_form.title)}</td>
          <td>#{Emails.escape(assignment.due_on)}</td>
          <td>#{Emails.escape(status_label(assignment.status))}</td>
          <td>#{Emails.escape(assignee_name(assignment))}</td>
        </tr>
        """
      end)

    """
    <h2>Inspections due for #{Emails.escape(org.name)}</h2>
    <p>The following inspections are due soon or overdue:</p>
    <table>
      <thead>
        <tr><th>Vehicle</th><th>Form</th><th>Due</th><th>Status</th><th>Assignee</th></tr>
      </thead>
      <tbody>#{rows}</tbody>
    </table>
    """
  end

  defp status_label(:overdue), do: "Overdue"
  defp status_label(_status), do: "Due Soon"

  defp assignee_name(%{assigned_to: %{profile: %{first_name: first, last_name: last}}}) do
    [first, last] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" ") |> blank_to_unassigned()
  end

  defp assignee_name(_assignment), do: "Unassigned"

  defp blank_to_unassigned(""), do: "Unassigned"
  defp blank_to_unassigned(name), do: name
end
