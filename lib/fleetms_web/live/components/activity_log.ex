defmodule FleetmsWeb.ActivityLog do
  @moduledoc """
  Renders an audit timeline for a record from its AshPaperTrail versions. Read-only, so
  it's a plain function component (unlike the comments section).

  Each version becomes one human line: lifecycle actions map to a verb ("resolved this
  issue", "started work"), and edits describe the changed key fields with their from→to
  values ("changed Priority from Low to High"). Noisy fields (descriptions, timestamps)
  are not surfaced. The `full_diff` change map stores each attribute as
  `%{"from" => .., "to" => ..}` when changed, `%{"to" => ..}` on create, and
  `%{"unchanged" => ..}` otherwise.

      <FleetmsWeb.ActivityLog.timeline
        kind={:issue}
        versions={@issue.paper_trail_versions}
        members={@members}
      />
  """
  use FleetmsWeb, :html

  @doc """
  Config per tracked resource: the verbs for named lifecycle actions, and the key fields
  (with a label and kind) whose changes are worth showing.
  """
  def config(:issue) do
    %{
      thing: "issue",
      verbs: %{
        create: "created this issue",
        resolve: "resolved this issue",
        close: "closed this issue",
        reopen: "reopened this issue",
        restore: "restored this issue",
        destroy: "archived this issue"
      },
      fields: [
        {"status", "Status", :atom},
        {"priority", "Priority", :atom},
        {"assigned_to_id", "Assignee", :member},
        {"title", "Title", :text},
        {"due_date", "Due date", :date},
        {"labels", "Labels", :list}
      ]
    }
  end

  def config(:work_order) do
    %{
      thing: "work order",
      verbs: %{
        create: "created this work order",
        start: "started work",
        complete: "completed this work order",
        reopen: "reopened this work order",
        restore: "restored this work order",
        destroy: "archived this work order"
      },
      fields: [
        {"status", "Status", :atom},
        {"assigned_to_id", "Assignee", :member},
        {"repair_category", "Repair category", :atom},
        {"mileage", "Mileage", :text}
      ]
    }
  end

  def config(:vehicle) do
    %{
      thing: "vehicle",
      verbs: %{
        create: "added this vehicle",
        restore: "restored this vehicle",
        destroy: "removed this vehicle"
      },
      fields: [
        {"status", "Status", :atom},
        {"name", "Name", :text},
        {"license_plate", "Plate", :text},
        {"mileage", "Mileage", :text},
        {"year", "Year", :text}
      ]
    }
  end

  attr :kind, :atom, required: true
  attr :versions, :list, required: true
  attr :members, :map, default: %{}

  def timeline(assigns) do
    assigns = assign(assigns, :events, to_events(assigns.versions, assigns.members, assigns.kind))

    ~H"""
    <ol class="relative space-y-6 border-s border-default ps-6">
      <li :for={event <- @events} class="relative">
        <span class="absolute -start-[1.9rem] mt-1 flex h-3 w-3 items-center justify-center rounded-full bg-brand ring-4 ring-white dark:ring-gray-800">
        </span>
        <p class="text-sm text-body">
          <span class="font-semibold text-heading">{event.actor}</span> {event.text}
        </p>
        <p class="text-xs text-body">{time_ago(event.at)}</p>
      </li>
      <li :if={@events == []} class="text-sm text-body">
        {gettext("No history yet.")}
      </li>
    </ol>
    """
  end

  @doc """
  A `user_id => display name` map for everyone in the org (any membership status), used
  to resolve both the actor and any assignee references in the timeline.
  """
  def member_names(scope) do
    Fleetms.Accounts.list_user_organizations!(
      scope: scope,
      query: [filter: [organization_id: scope.organization.id]],
      load: [user: [:email, profile: [:first_name, :last_name]]]
    )
    |> Map.new(fn membership -> {membership.user_id, person_name(membership.user)} end)
  end

  defp person_name(%{profile: %{first_name: first, last_name: last}} = user) do
    case [first, last] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" ") do
      "" -> to_string(user.email)
      name -> name
    end
  end

  defp person_name(%{email: email}) when not is_nil(email), do: to_string(email)
  defp person_name(_), do: gettext("A member")

  @doc "Turn version rows into `%{actor, at, text}` events, newest first."
  def to_events(versions, members, kind) do
    config = config(kind)

    versions
    |> Enum.sort_by(& &1.version_inserted_at, {:desc, DateTime})
    |> Enum.flat_map(&describe(&1, members, config))
  end

  defp describe(version, members, config) do
    actor = Map.get(members, version.user_id) || gettext("A member")
    base = %{actor: actor, at: version.version_inserted_at}

    cond do
      Map.has_key?(config.verbs, version.version_action_name) ->
        [Map.put(base, :text, Map.fetch!(config.verbs, version.version_action_name))]

      version.version_action_type == :create ->
        [Map.put(base, :text, "created this #{config.thing}")]

      true ->
        case field_change_text(version.changes, members, config.fields) do
          nil -> []
          text -> [Map.put(base, :text, text)]
        end
    end
  end

  # Describe the changed key fields on an update; nil if nothing worth showing.
  defp field_change_text(changes, members, fields) do
    parts =
      for {key, label, kind} <- fields,
          change = Map.get(changes, key),
          is_map(change) and Map.has_key?(change, "from") do
        "#{label} from #{format(kind, change["from"], members)} to #{format(kind, change["to"], members)}"
      end

    cond do
      parts != [] -> "changed " <> Enum.join(parts, ", ")
      changed_anything?(changes) -> "edited the details"
      true -> nil
    end
  end

  defp changed_anything?(changes) do
    Enum.any?(changes, fn {_key, value} -> is_map(value) and Map.has_key?(value, "from") end)
  end

  # --- value formatting ---

  defp format(_kind, nil, _members), do: "—"
  defp format(:member, id, members), do: Map.get(members, id, gettext("someone"))
  defp format(:list, [], _members), do: gettext("none")
  defp format(:list, values, _members) when is_list(values), do: Enum.join(values, ", ")
  defp format(:atom, value, _members), do: value |> to_string() |> humanize()
  defp format(_kind, value, _members), do: to_string(value)

  defp humanize(""), do: "—"
  defp humanize(value), do: value |> String.replace(["_", "-"], " ") |> String.capitalize()

  defp time_ago(nil), do: ""

  defp time_ago(%DateTime{} = at) do
    seconds = DateTime.diff(DateTime.utc_now(), at, :second)

    cond do
      seconds < 60 -> gettext("just now")
      seconds < 3600 -> gettext("%{n}m ago", n: div(seconds, 60))
      seconds < 86_400 -> gettext("%{n}h ago", n: div(seconds, 3600))
      seconds < 604_800 -> gettext("%{n}d ago", n: div(seconds, 86_400))
      true -> Calendar.strftime(at, "%b %-d, %Y")
    end
  end
end
