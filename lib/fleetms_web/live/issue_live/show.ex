defmodule FleetmsWeb.IssueLive.Show do
  @moduledoc """
  Issue detail page: a header summary with lifecycle actions, plus tabbed
  Details / Photos / Documents.

  The lifecycle buttons (resolve / close / reopen) call the issue's state-machine
  transition actions. Which buttons appear depends on the current status, so the
  UI can only offer legal transitions; the state machine still enforces them
  server-side. Resolve and close capture an optional comment via a small
  server-driven dialog. Photos and documents upload straight from here via the
  resources' `:upload` actions, exactly like the vehicle detail page.
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Format
  alias Fleetms.Scope
  alias Fleetms.VehicleIssues

  @person [:email, profile: [:first_name, :last_name]]
  @loads [
    :vehicle,
    :photos,
    :documents,
    :tags,
    :paper_trail_versions,
    :issue_watchers,
    reported_by: @person,
    assigned_to: @person
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(active_tab: "details", active_link: :issues, pending_transition: nil)
     |> allow_upload(:photos,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 10,
       max_file_size: 10_000_000
     )
     |> allow_upload(:documents,
       accept: ~w(.pdf .doc .docx .xls .xlsx .csv .txt .png .jpg .jpeg),
       max_entries: 10,
       max_file_size: 20_000_000
     )}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    scope = socket.assigns.current_scope

    case VehicleIssues.get_issue(id, scope: scope, load: @loads) do
      {:ok, issue} ->
        {:noreply,
         socket
         |> assign(:issue, issue)
         |> assign(:page_title, gettext("Issue #%{n}", n: issue.issue_number))
         |> assign(:members, FleetmsWeb.ActivityLog.member_names(scope))
         |> assign(:can_update, Scope.has_permission?(scope, :update_issue))
         |> assign(:can_create_work_order, Scope.has_permission?(scope, :create_work_order))
         |> assign_watch_state(issue, scope)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("That issue could not be found."))
         |> push_navigate(to: ~p"/o/#{org(socket)}/issues")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      organizations={@organizations}
      unread_notifications_count={@unread_notifications_count}
      recent_notifications={@recent_notifications}
      notifications_open={@notifications_open}
    >
      <.breadcrumbs items={[
        %{label: gettext("Dashboard"), path: ~p"/o/#{org(assigns)}", icon: "fa-house"},
        %{label: gettext("Issues"), path: ~p"/o/#{org(assigns)}/issues"},
        %{label: "##{@issue.issue_number}"}
      ]} />

      <%!-- Header summary --%>
      <div class="mt-4 flex flex-col gap-4 rounded-base border border-default bg-white p-4 shadow-sm dark:bg-gray-800 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <div class="flex items-center gap-3">
            <h1 class="text-xl font-bold text-heading">
              <span class="text-body">#{@issue.issue_number}</span> {@issue.title}
            </h1>
          </div>
          <div class="mt-2 flex flex-wrap items-center gap-2">
            <.badge color={status_color(@issue.status)}>{humanize_status(@issue.status)}</.badge>
            <.badge color={priority_color(@issue.priority)}>
              {gettext("Priority:")} {@issue.priority}
            </.badge>
            <span class="text-sm text-body">
              {gettext("on")} {vehicle_name(@issue)}
            </span>
          </div>
        </div>

        <div class="flex flex-wrap items-center gap-2">
          <.button
            :if={@can_update and @issue.status == :open}
            variant="success"
            phx-click="begin-transition"
            phx-value-action="resolve"
          >
            <.icon name="fa-circle-check" class="me-2" /> {gettext("Resolve")}
          </.button>
          <.button
            :if={@can_update and @issue.status in [:open, :resolved]}
            variant="secondary"
            phx-click="begin-transition"
            phx-value-action="close"
          >
            <.icon name="fa-xmark" class="me-2" /> {gettext("Close")}
          </.button>
          <.button
            :if={@can_update and @issue.status in [:resolved, :closed]}
            variant="secondary"
            phx-click="reopen"
            data-confirm={gettext("Reopen this issue?")}
          >
            <.icon name="fa-rotate-left" class="me-2" /> {gettext("Reopen")}
          </.button>
          <.button
            variant={if @watching, do: "secondary", else: "ghost"}
            phx-click={if @watching, do: "unwatch", else: "watch"}
            title={
              if @watchers_count > 0,
                do: gettext("%{n} watching", n: @watchers_count),
                else: gettext("Get notified when this issue is resolved or closed")
            }
          >
            <.icon name={if @watching, do: "fa-eye-slash", else: "fa-eye"} class="me-2" />
            {if @watching, do: gettext("Watching"), else: gettext("Watch")}
            <span :if={@watchers_count > 0} class="ms-1 text-xs opacity-70">
              {@watchers_count}
            </span>
          </.button>
          <.button :if={@can_update} navigate={~p"/o/#{org(assigns)}/issues/#{@issue.id}/edit"}>
            <.icon name="fa-pen-to-square" class="me-2" /> {gettext("Edit")}
          </.button>

          <%!-- Link the issue straight into a new work order, or jump to the one it's on. --%>
          <.button
            :if={@issue.work_order_id}
            variant="secondary"
            navigate={~p"/o/#{org(assigns)}/work-orders/#{@issue.work_order_id}"}
          >
            <.icon name="fa-screwdriver-wrench" class="me-2" /> {gettext("View work order")}
          </.button>
          <.button
            :if={
              (@can_create_work_order and is_nil(@issue.work_order_id) and @issue.vehicle_id) &&
                @issue.status in [:open, :resolved]
            }
            variant="secondary"
            navigate={
              ~p"/o/#{org(assigns)}/work-orders/new?#{%{"vehicle_id" => @issue.vehicle_id, "issue_ids" => [@issue.id]}}"
            }
          >
            <.icon name="fa-screwdriver-wrench" class="me-2" /> {gettext("Create work order")}
          </.button>
        </div>
      </div>

      <div class="mt-4 rounded-base border border-default bg-white px-4 shadow-sm dark:bg-gray-800">
        <.tabs active={@active_tab} on_select="select-tab">
          <:tab name="details" label={gettext("Details")} icon="fa-list-check">
            <.list>
              <:item title={gettext("Status")}>{humanize_status(@issue.status)}</:item>
              <:item title={gettext("Priority")}>{@issue.priority}</:item>
              <:item title={gettext("Vehicle")}>{vehicle_name(@issue)}</:item>
              <:item title={gettext("Reported by")}>{person_name(@issue.reported_by)}</:item>
              <:item title={gettext("Assigned to")}>{assignee_name(@issue)}</:item>
              <:item title={gettext("Reported")}>
                {Format.datetime(@issue.reported_at, org(assigns))}
              </:item>
              <:item title={gettext("Due date")}>{Format.date(@issue.due_date, org(assigns))}</:item>
              <:item title={gettext("Mileage")}>
                {Format.distance(@issue.mileage, org(assigns))}
              </:item>
              <:item title={gettext("Engine hours")}>{present(@issue.hours)}</:item>
              <:item :if={@issue.tags != []} title={gettext("Tags")}>
                <.tag_list tags={@issue.tags} />
              </:item>
              <:item :if={@issue.resolved_at} title={gettext("Resolved")}>
                {Format.datetime(@issue.resolved_at, org(assigns))}
              </:item>
              <:item :if={@issue.closed_at} title={gettext("Closed")}>
                {Format.datetime(@issue.closed_at, org(assigns))}
              </:item>
            </.list>

            <div :if={@issue.description} class="mt-6">
              <h3 class="mb-2 text-sm font-semibold uppercase text-heading">
                {gettext("Description")}
              </h3>
              <div class="format dark:format-invert max-w-none">{raw(@issue.description)}</div>
            </div>

            <div :if={present?(@issue.resolve_comments)} class="mt-6">
              <h3 class="mb-2 text-sm font-semibold uppercase text-heading">
                {gettext("Resolution notes")}
              </h3>
              <p class="whitespace-pre-wrap text-sm text-body">{@issue.resolve_comments}</p>
            </div>

            <div :if={present?(@issue.close_comments)} class="mt-6">
              <h3 class="mb-2 text-sm font-semibold uppercase text-heading">
                {gettext("Closing notes")}
              </h3>
              <p class="whitespace-pre-wrap text-sm text-body">{@issue.close_comments}</p>
            </div>
          </:tab>

          <:tab name="photos" label={gettext("Photos")} icon="fa-image">
            <div
              :if={@issue.photos != []}
              class="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4"
            >
              <div :for={photo <- @issue.photos} class="group relative">
                <a href={storage_url(photo.image_key)} target="_blank" rel="noopener">
                  <img
                    src={storage_url(photo.thumbnail_key)}
                    alt={photo.caption || @issue.title}
                    class="h-32 w-full rounded-lg object-cover"
                  />
                </a>
                <button
                  :if={@can_update}
                  type="button"
                  phx-click="delete-photo"
                  phx-value-id={photo.id}
                  data-confirm={gettext("Delete this photo?")}
                  class="absolute right-2 top-2 hidden h-8 w-8 items-center justify-center rounded-full bg-white/90 text-fg-danger shadow group-hover:flex dark:bg-gray-900/90"
                >
                  <.icon name="fa-trash" class="text-sm" />
                </button>
              </div>
            </div>
            <p :if={@issue.photos == []} class="text-body">{gettext("No photos yet.")}</p>

            <.upload_panel
              :if={@can_update}
              upload={@uploads.photos}
              submit="save-photos"
              cancel="cancel-photo"
              upload_error={&upload_error/1}
              label={gettext("Upload photos")}
              hint={gettext("PNG, JPG or WEBP up to 10MB")}
            />
          </:tab>

          <:tab name="documents" label={gettext("Documents")} icon="fa-file-lines">
            <ul :if={@issue.documents != []} class="divide-y divide-default">
              <li :for={doc <- @issue.documents} class="flex items-center gap-3 py-3">
                <span class="flex h-10 w-10 items-center justify-center rounded-lg bg-brand-softer text-fg-brand">
                  <.icon name="fa-file" />
                </span>
                <div class="min-w-0 flex-1">
                  <p class="truncate font-medium text-heading">{doc.filename}</p>
                  <p class="text-sm text-body">
                    {present(doc.content_type)} · {humanize_bytes(doc.byte_size)}
                  </p>
                </div>
                <.link
                  href={storage_url(doc.storage_key)}
                  target="_blank"
                  rel="noopener"
                  class="rounded p-2 text-body hover:bg-gray-100 hover:text-heading dark:hover:bg-gray-700"
                >
                  <.icon name="fa-download" />
                </.link>
                <button
                  :if={@can_update}
                  type="button"
                  phx-click="delete-document"
                  phx-value-id={doc.id}
                  data-confirm={gettext("Delete %{name}?", name: doc.filename)}
                  class="rounded p-2 text-fg-danger hover:bg-danger-soft"
                >
                  <.icon name="fa-trash" />
                </button>
              </li>
            </ul>
            <p :if={@issue.documents == []} class="text-body">{gettext("No documents yet.")}</p>

            <.upload_panel
              :if={@can_update}
              upload={@uploads.documents}
              submit="save-documents"
              cancel="cancel-document"
              upload_error={&upload_error/1}
              label={gettext("Upload documents")}
              hint={gettext("PDF, Office, images or text up to 20MB")}
            />
          </:tab>

          <:tab name="comments" label={gettext("Comments")} icon="fa-comments">
            <.live_component
              module={FleetmsWeb.CommentsSection}
              id={"comments-#{@issue.id}"}
              scope={@current_scope}
              parent_key={:issue_id}
              parent_id={@issue.id}
            />
          </:tab>

          <:tab name="history" label={gettext("History")} icon="fa-clock-rotate-left">
            <FleetmsWeb.ActivityLog.timeline
              kind={:issue}
              versions={@issue.paper_trail_versions}
              members={@members}
            />
          </:tab>
        </.tabs>
      </div>

      <%!-- Lifecycle comment dialog (server-driven) --%>
      <div
        :if={@pending_transition}
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
      >
        <div class="w-full max-w-md rounded-base border border-default bg-white p-6 shadow-lg dark:bg-gray-800">
          <h3 class="text-lg font-semibold text-heading">{transition_title(@pending_transition)}</h3>
          <form phx-submit="confirm-transition" class="mt-4">
            <.input
              type="textarea"
              name="comment"
              value=""
              label={transition_comment_label(@pending_transition)}
            />
            <div class="mt-4 flex items-center gap-3">
              <.button type="submit" phx-disable-with={gettext("Saving…")}>
                {transition_confirm_label(@pending_transition)}
              </.button>
              <.button type="button" variant="secondary" phx-click="cancel-transition">
                {gettext("Cancel")}
              </.button>
            </div>
          </form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :upload, :any, required: true
  attr :submit, :string, required: true
  attr :cancel, :string, required: true
  attr :upload_error, :any, required: true
  attr :label, :string, required: true
  attr :hint, :string, required: true

  defp upload_panel(assigns) do
    ~H"""
    <form
      phx-submit={@submit}
      phx-change="validate-upload"
      id={"#{@upload.ref}-form"}
      class="mt-6 border-t border-default pt-4"
    >
      <label
        phx-drop-target={@upload.ref}
        class="flex cursor-pointer flex-col items-center justify-center rounded-lg border-2 border-dashed border-default-medium bg-gray-50 p-6 text-center hover:bg-gray-100 dark:bg-gray-700 dark:hover:bg-gray-600"
      >
        <.icon name="fa-cloud-arrow-up" class="mb-2 text-2xl text-body" />
        <span class="text-sm text-body">
          <span class="font-semibold text-heading">{gettext("Click to upload")}</span>
          {gettext("or drag and drop")}
        </span>
        <span class="mt-1 text-xs text-body">{@hint}</span>
        <.live_file_input upload={@upload} aria-label={gettext("Upload file")} class="hidden" />
      </label>

      <p :for={err <- upload_errors(@upload)} class="mt-2 text-sm text-fg-danger">
        {@upload_error.(err)}
      </p>

      <div :for={entry <- @upload.entries} class="mt-3 flex items-center gap-3">
        <.live_img_preview
          :if={String.starts_with?(entry.client_type, "image/")}
          entry={entry}
          class="h-12 w-12 rounded object-cover"
        />
        <span
          :if={not String.starts_with?(entry.client_type, "image/")}
          class="flex h-12 w-12 items-center justify-center rounded bg-gray-100 text-gray-400 dark:bg-gray-700"
        >
          <.icon name="fa-file" />
        </span>
        <div class="min-w-0 flex-1">
          <p class="truncate text-sm text-heading">{entry.client_name}</p>
          <progress value={entry.progress} max="100" class="h-1.5 w-full">{entry.progress}%</progress>
          <p :for={err <- upload_errors(@upload, entry)} class="text-xs text-fg-danger">
            {@upload_error.(err)}
          </p>
        </div>
        <button
          type="button"
          phx-click={@cancel}
          phx-value-ref={entry.ref}
          class="rounded p-1.5 text-body hover:text-heading"
          aria-label={gettext("Cancel")}
        >
          <.icon name="fa-xmark" />
        </button>
      </div>

      <.button :if={@upload.entries != []} type="submit" class="mt-4">{@label}</.button>
    </form>
    """
  end

  @impl true
  def handle_event("select-tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_event("watch", _params, socket) do
    scope = socket.assigns.current_scope
    issue = socket.assigns.issue
    VehicleIssues.watch_issue(%{issue_id: issue.id, user_id: scope.user.id}, scope: scope)

    {:noreply, refresh_watchers(socket)}
  end

  def handle_event("unwatch", _params, socket) do
    scope = socket.assigns.current_scope
    issue = socket.assigns.issue

    case Enum.find(issue.issue_watchers, &(&1.user_id == scope.user.id)) do
      nil -> :ok
      watcher -> VehicleIssues.unwatch_issue(watcher, scope: scope)
    end

    {:noreply, refresh_watchers(socket)}
  end

  def handle_event("validate-upload", _params, socket), do: {:noreply, socket}

  def handle_event("cancel-photo", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :photos, ref)}
  end

  def handle_event("cancel-document", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :documents, ref)}
  end

  # --- lifecycle transitions ---

  def handle_event("begin-transition", %{"action" => action}, socket)
      when action in ["resolve", "close"] do
    {:noreply, assign(socket, :pending_transition, String.to_existing_atom(action))}
  end

  def handle_event("cancel-transition", _params, socket) do
    {:noreply, assign(socket, :pending_transition, nil)}
  end

  def handle_event("confirm-transition", %{"comment" => comment}, socket) do
    scope = socket.assigns.current_scope
    issue = socket.assigns.issue
    comment = blank_to_nil(comment)

    result =
      case socket.assigns.pending_transition do
        :resolve -> VehicleIssues.resolve_issue(issue, %{resolve_comments: comment}, scope: scope)
        :close -> VehicleIssues.close_issue(issue, %{close_comments: comment}, scope: scope)
      end

    socket = assign(socket, :pending_transition, nil)

    case result do
      {:ok, _} -> {:noreply, socket |> refresh() |> put_flash(:info, gettext("Issue updated."))}
      {:error, _} -> {:noreply, put_flash(socket, :error, gettext("Could not update the issue."))}
    end
  end

  def handle_event("reopen", _params, socket) do
    scope = socket.assigns.current_scope

    case VehicleIssues.reopen_issue(socket.assigns.issue, %{}, scope: scope) do
      {:ok, _} -> {:noreply, socket |> refresh() |> put_flash(:info, gettext("Issue reopened."))}
      {:error, _} -> {:noreply, put_flash(socket, :error, gettext("Could not reopen the issue."))}
    end
  end

  # --- uploads ---

  def handle_event("save-photos", _params, socket) do
    scope = socket.assigns.current_scope
    issue = socket.assigns.issue

    results =
      consume_uploaded_entries(socket, :photos, fn %{path: path}, _entry ->
        {:ok,
         VehicleIssues.upload_issue_photo(%{issue_id: issue.id, source_path: path}, scope: scope)}
      end)

    {:noreply, finish_upload(socket, results, gettext("Photos uploaded."))}
  end

  def handle_event("save-documents", _params, socket) do
    scope = socket.assigns.current_scope
    issue = socket.assigns.issue

    results =
      consume_uploaded_entries(socket, :documents, fn %{path: path}, entry ->
        {:ok,
         VehicleIssues.upload_issue_document(
           %{
             issue_id: issue.id,
             source_path: path,
             filename: entry.client_name,
             content_type: entry.client_type,
             byte_size: entry.client_size
           },
           scope: scope
         )}
      end)

    {:noreply, finish_upload(socket, results, gettext("Documents uploaded."))}
  end

  def handle_event("delete-photo", %{"id" => id}, socket) do
    delete_child(socket, socket.assigns.issue.photos, id, &VehicleIssues.delete_issue_photo/2)
  end

  def handle_event("delete-document", %{"id" => id}, socket) do
    delete_child(
      socket,
      socket.assigns.issue.documents,
      id,
      &VehicleIssues.delete_issue_document/2
    )
  end

  defp finish_upload(socket, results, success_message) do
    if Enum.any?(results, &match?({:error, _}, &1)) do
      socket |> refresh() |> put_flash(:error, gettext("Some files could not be saved."))
    else
      socket |> refresh() |> put_flash(:info, success_message)
    end
  end

  defp delete_child(socket, collection, id, destroy_fun) do
    scope = socket.assigns.current_scope

    case Enum.find(collection, &(&1.id == id)) do
      nil -> {:noreply, socket}
      record -> destroy_fun.(record, scope: scope) && {:noreply, refresh(socket)}
    end
  end

  defp refresh(socket) do
    scope = socket.assigns.current_scope
    issue = VehicleIssues.get_issue!(socket.assigns.issue.id, scope: scope, load: @loads)
    assign(socket, :issue, issue)
  end

  # --- transition dialog copy ---

  defp transition_title(:resolve), do: gettext("Resolve issue")
  defp transition_title(:close), do: gettext("Close issue")

  defp transition_comment_label(:resolve), do: gettext("Resolution notes (optional)")
  defp transition_comment_label(:close), do: gettext("Closing notes (optional)")

  defp transition_confirm_label(:resolve), do: gettext("Resolve")
  defp transition_confirm_label(:close), do: gettext("Close")

  # --- display helpers ---

  defp storage_url(nil), do: nil
  defp storage_url(key), do: Fleetms.Storage.url(key)

  defp vehicle_name(%{vehicle: %{name: name}}), do: name
  defp vehicle_name(_), do: "—"

  defp assignee_name(%{assigned_to: %_{} = user}), do: person_name(user)
  defp assignee_name(_), do: "—"

  defp person_name(%{profile: %{first_name: first, last_name: last}} = user) do
    case [first, last] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" ") do
      "" -> to_string(user.email)
      name -> name
    end
  end

  defp person_name(%{email: email}), do: to_string(email)
  defp person_name(_), do: "—"

  defp humanize_status(status), do: status |> to_string() |> String.capitalize()

  defp status_color(:open), do: "info"
  defp status_color(:resolved), do: "success"
  defp status_color(:closed), do: "gray"
  defp status_color(_), do: "gray"

  defp priority_color(:High), do: "danger"
  defp priority_color(:Medium), do: "warning"
  defp priority_color(:Low), do: "info"
  defp priority_color(_), do: "gray"

  defp present(nil), do: "—"
  defp present(""), do: "—"
  defp present(value), do: value

  defp present?(value), do: value not in [nil, ""]

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(_), do: nil

  defp humanize_bytes(nil), do: ""
  defp humanize_bytes(bytes) when bytes < 1_024, do: "#{bytes} B"
  defp humanize_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1_024, 1)} KB"
  defp humanize_bytes(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  defp upload_error(:too_large), do: gettext("File is too large.")
  defp upload_error(:too_many_files), do: gettext("Too many files.")
  defp upload_error(:not_accepted), do: gettext("That file type isn't allowed.")
  defp upload_error(_), do: gettext("Invalid file.")

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization

  # Reloads the issue's watchers after a watch/unwatch and recomputes the toggle.
  defp refresh_watchers(socket) do
    scope = socket.assigns.current_scope
    issue = VehicleIssues.get_issue!(socket.assigns.issue.id, scope: scope, load: @loads)

    socket
    |> assign(:issue, issue)
    |> assign_watch_state(issue, scope)
  end

  defp assign_watch_state(socket, issue, scope) do
    watchers = issue.issue_watchers || []

    socket
    |> assign(:watching, Enum.any?(watchers, &(&1.user_id == scope.user.id)))
    |> assign(:watchers_count, length(watchers))
  end
end
