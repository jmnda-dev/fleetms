defmodule Fleetms.Maintenance.ReminderDigest do
  @moduledoc """
  Builds and sends the daily "service due" email digest for one organization.

  Called per tenant by the `ServiceReminder.send_due_digest` scheduled action (which
  AshOban runs once per organization). It gathers the org's due-soon / overdue
  service reminders and emails a summary to the organization's owner(s). It is
  purely a notifier — a reminder's `due_status` is derived live and always correct;
  this just tells someone about it. Runs unauthorized (a system job, no actor).

  Mirrors `Fleetms.VehicleManagement.RenewalDigest`.
  """
  require Ash.Query

  import Swoosh.Email

  alias Fleetms.{Accounts, Emails, Mailer}
  alias Fleetms.Maintenance.ServiceReminder

  @due_statuses [:due_soon, :overdue]

  @doc """
  Sends the digest for the given tenant (an `org_<id>` schema string). Returns
  `{:ok, count}` where `count` is how many recipients were emailed (0 if nothing is
  due or the org has no reachable owner).
  """
  @spec deliver_for_tenant(String.t()) :: {:ok, non_neg_integer()}
  def deliver_for_tenant(tenant) do
    case due_reminders(tenant) do
      [] ->
        {:ok, 0}

      reminders ->
        org_id = org_id_from_tenant(tenant)
        recipients = owner_emails(org_id)

        if recipients == [] do
          {:ok, 0}
        else
          org = Accounts.get_organization!(org_id, authorize?: false)
          deliver(recipients, org, reminders)
          {:ok, length(recipients)}
        end
    end
  end

  defp due_reminders(tenant) do
    ServiceReminder
    |> Ash.Query.load([:due_status, :service_task_name, :vehicle_name])
    |> Ash.Query.filter(due_status in ^@due_statuses)
    |> Ash.Query.sort(next_due_date: :asc)
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

  defp deliver(recipients, org, reminders) do
    new()
    |> from({"FleetMS", "noreply@fleetms.app"})
    |> to(recipients)
    |> subject("#{length(reminders)} service reminder(s) due — #{org.name}")
    |> html_body(body(org, reminders))
    |> Mailer.deliver!()
  end

  defp body(org, reminders) do
    rows =
      Enum.map_join(reminders, "", fn reminder ->
        """
        <tr>
          <td>#{Emails.escape(reminder.vehicle_name)}</td>
          <td>#{Emails.escape(reminder.service_task_name)}</td>
          <td>#{Emails.escape(next_due(reminder))}</td>
          <td>#{Emails.escape(humanize(reminder.due_status))}</td>
        </tr>
        """
      end)

    """
    <h2>Service due for #{Emails.escape(org.name)}</h2>
    <p>The following vehicle service tasks are due soon or overdue:</p>
    <table>
      <thead>
        <tr><th>Vehicle</th><th>Service task</th><th>Next due</th><th>Status</th></tr>
      </thead>
      <tbody>#{rows}</tbody>
    </table>
    """
  end

  defp next_due(reminder) do
    [mileage(reminder.next_due_mileage), date(reminder.next_due_date)]
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> "—"
      parts -> Enum.join(parts, " · ")
    end
  end

  defp mileage(nil), do: nil
  defp mileage(m), do: "#{Decimal.to_string(m, :normal)} mi"

  defp date(nil), do: nil
  defp date(d), do: Date.to_string(d)

  defp humanize(status),
    do: status |> to_string() |> String.replace("_", " ") |> String.capitalize()
end
