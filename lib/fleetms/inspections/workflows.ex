defmodule Fleetms.Inspections.Workflows do
  @moduledoc """
  Runs an inspection form's workflows against a freshly graded inspection.

  A workflow is a `when → then`: if its `trigger` fires on the submitted
  inspection, each of its `actions` runs. Triggers are matched from the already
  computed grade (the overall `result` and each answer's `status`); actions have
  side effects — `open_issue` raises a `VehicleIssues.Issue`, `notify` sends an
  in-app notification.

  **Best-effort, at-most-once.** Each action is isolated: a failing or crashing
  action is logged and the rest still run, and the run as a whole always succeeds
  so the caller can stamp `workflows_ran_at` and never re-run it. This deliberately
  favours "no duplicate issues on retry" over "guaranteed delivery" — the same
  trade-off `Issue`'s own after-transaction notifications make. Callers pass the
  inspection already loaded with everything the engine reads (see `run/2`).
  """
  require Ash.Query
  require Logger

  import Swoosh.Email

  alias Fleetms.Accounts
  alias Fleetms.Accounts.UserRole
  alias Fleetms.Inspections.Inspection
  alias Fleetms.Mailer

  @load [
    :failures,
    vehicle: [:name, :mileage],
    inspection_form: [:title],
    inspection_form_version: [],
    submitted_by: [:email, profile: [:first_name, :last_name]]
  ]

  @doc """
  What the inspection must be loaded with before calling `run/2`. The version's
  embedded `schema` (which carries the workflows) is always present on the struct.
  """
  def load_requirements, do: @load

  @doc """
  Runs every enabled workflow on `inspection`. `opts` must carry `:tenant`; an
  optional `:actor` is only used as the notification actor. Returns `:ok`.
  """
  def run(%Inspection{} = inspection, opts) do
    inspection
    |> workflows()
    |> Enum.filter(& &1.enabled)
    |> Enum.each(fn workflow ->
      if fires?(unwrap(workflow.trigger), inspection) do
        run_actions(workflow, inspection, opts)
      end
    end)

    :ok
  end

  defp workflows(inspection) do
    case inspection.inspection_form_version do
      %{schema: %{workflows: workflows}} when is_list(workflows) -> workflows
      _ -> []
    end
  end

  # A union member arrives as %Ash.Union{value: ...}; embedded structs pass through.
  defp unwrap(%Ash.Union{value: value}), do: value
  defp unwrap(other), do: other

  # --- Trigger matching -----------------------------------------------------

  defp fires?(%{type: :inspection_submitted}, _inspection), do: true
  defp fires?(%{type: :inspection_failed}, inspection), do: inspection.result == :failed

  defp fires?(%{type: :any_item_failed}, inspection),
    do: Enum.any?(inspection.answers, &failed?/1)

  defp fires?(%{type: :item_failed, item_id: item_id}, inspection) do
    Enum.any?(inspection.answers, &(&1.item_id == item_id and failed?(&1)))
  end

  defp fires?(_trigger, _inspection), do: false

  defp failed?(answer), do: answer.status == :fail

  # --- Action dispatch ------------------------------------------------------

  defp run_actions(workflow, inspection, opts) do
    Enum.each(workflow.actions, fn action ->
      safe_run_action(unwrap(action), workflow, inspection, opts)
    end)
  end

  defp safe_run_action(action, workflow, inspection, opts) do
    run_action(action, workflow, inspection, opts)
  rescue
    error ->
      Logger.error(
        "Inspection workflow action crashed for inspection #{inspection.id}: " <>
          Exception.message(error)
      )

      :ok
  end

  defp run_action(%{type: :open_issue} = action, workflow, inspection, opts) do
    open_issue(action, workflow, inspection, opts)
  end

  defp run_action(%{type: :notify} = action, workflow, inspection, opts) do
    notify(action, workflow, inspection, opts)
  end

  defp run_action(_action, _workflow, _inspection, _opts), do: :ok

  # --- open_issue -----------------------------------------------------------

  defp open_issue(_action, _workflow, %{submitted_by: nil} = inspection, _opts) do
    Logger.warning(
      "Skipping open_issue for inspection #{inspection.id}: no submitter to report the issue as."
    )

    :ok
  end

  defp open_issue(action, workflow, inspection, opts) do
    failures = relevant_failures(workflow, inspection)
    subs = substitutions(inspection, failures)

    attrs = %{
      title: render(action.title_template, subs),
      description: issue_description(inspection, failures),
      priority: action.priority,
      vehicle_id: inspection.vehicle_id,
      assigned_to_id: assignee_id(action, inspection),
      mileage: inspection.vehicle && inspection.vehicle.mileage
    }

    case Fleetms.VehicleIssues.create_issue(attrs,
           actor: inspection.submitted_by,
           tenant: opts[:tenant],
           authorize?: false
         ) do
      {:ok, issue} ->
        link_failures(failures, issue, opts)

      {:error, error} ->
        Logger.error(
          "Inspection workflow open_issue failed for inspection #{inspection.id}: #{inspect(error)}"
        )

        :ok
    end
  end

  defp assignee_id(%{assign_to: :submitter}, inspection), do: inspection.submitted_by_id
  defp assignee_id(%{assign_to: :user, assignee_user_id: user_id}, _inspection), do: user_id
  defp assignee_id(_action, _inspection), do: nil

  # For an item-scoped trigger, only that item's failure(s) belong to the issue;
  # otherwise the whole inspection's failures do.
  defp relevant_failures(workflow, inspection) do
    case unwrap(workflow.trigger) do
      %{type: :item_failed, item_id: item_id} ->
        Enum.filter(inspection.failures, &(&1.item_id == item_id))

      _ ->
        inspection.failures
    end
  end

  defp link_failures(failures, issue, opts) do
    Enum.each(failures, fn failure ->
      Fleetms.Inspections.link_inspection_failure_issue(failure, %{issue_id: issue.id},
        tenant: opts[:tenant],
        authorize?: false
      )
    end)
  end

  defp issue_description(inspection, failures) do
    form = inspection.inspection_form && inspection.inspection_form.title

    intro =
      "<p>Opened automatically from the inspection <strong>#{escape(form || "—")}</strong> " <>
        "on <strong>#{escape(vehicle_name(inspection))}</strong>.</p>"

    case failures do
      [] ->
        intro

      _ ->
        items =
          failures
          |> Enum.map(fn failure ->
            "<li><strong>#{escape(failure.item_label)}</strong>: #{escape(failure.value_snapshot)}</li>"
          end)
          |> Enum.join()

        intro <> "<p>Failed checks:</p><ul>#{items}</ul>"
    end
  end

  # --- notify ---------------------------------------------------------------

  defp notify(action, workflow, inspection, opts) do
    case notify_recipients(action, inspection, opts) do
      [] ->
        Logger.warning("Skipping notify for inspection #{inspection.id}: no recipients resolved.")

        :ok

      recipients ->
        subs = substitutions(inspection, relevant_failures(workflow, inspection))
        title = render(action.title_template, subs)
        body = action.body_template && render(action.body_template, subs)
        channel = Map.get(action, :channel) || :in_app

        Enum.each(recipients, fn recipient ->
          if channel in [:in_app, :both],
            do: deliver_in_app(recipient, title, body, inspection, opts)

          if channel in [:email, :both], do: deliver_email(recipient, title, body, inspection)
        end)

        :ok
    end
  end

  # Resolves the action's target to a list of `%{id:, email:}` recipients (email may
  # be nil for username-only members, who then only receive the in-app notification).
  defp notify_recipients(%{to: :submitter}, %{submitted_by: nil}, _opts), do: []

  defp notify_recipients(%{to: :submitter}, inspection, _opts),
    do: [%{id: inspection.submitted_by_id, email: email_of(inspection.submitted_by)}]

  defp notify_recipients(%{to: :user, recipient_user_id: nil}, _inspection, _opts), do: []

  defp notify_recipients(%{to: :user, recipient_user_id: user_id}, _inspection, _opts),
    do: users_by_ids([user_id])

  defp notify_recipients(%{to: :role, role_id: nil}, _inspection, _opts), do: []

  defp notify_recipients(%{to: :role, role_id: role_id}, _inspection, opts) do
    UserRole
    |> Ash.Query.filter(role_id == ^role_id)
    |> Ash.Query.load(user: [:email])
    |> Ash.read!(tenant: opts[:tenant], authorize?: false)
    |> Enum.map(& &1.user)
    |> to_recipients()
  end

  defp notify_recipients(%{to: :owners}, _inspection, opts) do
    Accounts.list_user_organizations!(
      query: [filter: [organization_id: org_id_from_tenant(opts[:tenant]), owner?: true]],
      load: [user: [:email]],
      authorize?: false
    )
    |> Enum.map(& &1.user)
    |> to_recipients()
  end

  defp notify_recipients(_action, _inspection, _opts), do: []

  defp users_by_ids(ids) do
    Accounts.User
    |> Ash.Query.filter(id in ^ids)
    |> Ash.Query.load([:email])
    |> Ash.read!(authorize?: false)
    |> to_recipients()
  end

  defp to_recipients(users) do
    users
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&%{id: &1.id, email: email_of(&1)})
    |> Enum.uniq_by(& &1.id)
  end

  defp email_of(%{email: nil}), do: nil
  defp email_of(%{email: email}), do: to_string(email)
  defp email_of(_user), do: nil

  # The tenant may arrive as the `org_<id>` schema string or the Organization struct.
  defp org_id_from_tenant("org_" <> id), do: id
  defp org_id_from_tenant(%{id: id}), do: id
  defp org_id_from_tenant(tenant), do: tenant

  defp deliver_in_app(recipient, title, body, inspection, opts) do
    Fleetms.Notifications.notify_if_subscribed(
      %{
        recipient_id: recipient.id,
        actor_id: inspection.submitted_by_id,
        type: "inspection_workflow",
        title: title,
        body: body,
        path: "/inspections/#{inspection.id}"
      },
      tenant: opts[:tenant],
      authorize?: false
    )
  end

  # No email address (e.g. a username-only member) — the in-app bell is the only reach.
  defp deliver_email(%{email: nil}, _title, _body, _inspection), do: :ok

  defp deliver_email(%{email: email}, title, body, inspection) do
    new()
    |> from({"FleetMS", "noreply@fleetms.app"})
    |> to(email)
    |> subject(title)
    |> html_body(email_body(title, body, inspection))
    |> Mailer.deliver!()

    :ok
  end

  defp email_body(title, body, inspection) do
    message = if body in [nil, ""], do: "", else: "<p>#{escape(body)}</p>"

    """
    <h2>#{escape(title)}</h2>
    #{message}
    <p>Vehicle: <strong>#{escape(vehicle_name(inspection))}</strong></p>
    <p>Form: <strong>#{escape(form_title(inspection))}</strong></p>
    """
  end

  defp form_title(inspection),
    do: (inspection.inspection_form && inspection.inspection_form.title) || "—"

  # --- Template rendering ---------------------------------------------------

  # Placeholders available in *_template fields. `{item}` is the primary failed
  # item for the workflow (the specific one for an item trigger, else the first).
  defp substitutions(inspection, failures) do
    %{
      "{vehicle}" => vehicle_name(inspection),
      "{form}" => (inspection.inspection_form && inspection.inspection_form.title) || "",
      "{result}" => to_string(inspection.result),
      "{failed_count}" => to_string(length(inspection.failures)),
      "{submitter}" => submitter_name(inspection),
      "{item}" => (List.first(failures) && List.first(failures).item_label) || ""
    }
  end

  defp render(template, subs) do
    Enum.reduce(subs, template, fn {placeholder, value}, acc ->
      String.replace(acc, placeholder, value)
    end)
  end

  defp vehicle_name(inspection), do: (inspection.vehicle && inspection.vehicle.name) || "vehicle"

  defp submitter_name(%{submitted_by: %{profile: %{first_name: first, last_name: last}}})
       when is_binary(first) or is_binary(last) do
    [first, last] |> Enum.reject(&is_nil/1) |> Enum.join(" ")
  end

  defp submitter_name(%{submitted_by: %{email: email}}) when is_binary(email), do: email
  defp submitter_name(_inspection), do: "a member"

  # Minimal HTML escaping for user-authored labels/values placed into the issue
  # description (which is itself sanitized on the way in by the issue action).
  defp escape(nil), do: ""

  defp escape(value) do
    value
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end
end
