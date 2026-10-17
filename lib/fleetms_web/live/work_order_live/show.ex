defmodule FleetmsWeb.WorkOrderLive.Show do
  @moduledoc """
  Work order detail page: a header with lifecycle actions (`start` / `complete` /
  `reopen`), then tabs — a structured **Overview** (details, cost breakdown, line
  items, linked issues), a printable **Print view** laid out like an A4 work-order
  sheet (isolated for printing via a scoped `@media print` rule; the Print button
  opens the browser dialog), and **Photos** / **Documents** tabs for uploaded media.
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Format
  alias Fleetms.Maintenance
  alias Fleetms.Scope

  # Extra loads the show needs on top of the detail action's own loads: the tag chips
  # and the History tab. Applied on the first load and every reload so neither is left
  # unloaded after a lifecycle transition.
  @loads [:tags, :paper_trail_versions]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(active_tab: "overview", active_link: :maintenance)
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

    case Maintenance.get_work_order(id, scope: scope, load: @loads) do
      {:ok, work_order} ->
        {:noreply, assign_work_order(socket, work_order)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("That work order could not be found."))
         |> push_navigate(to: ~p"/o/#{org(socket)}/work-orders")}
    end
  end

  defp assign_work_order(socket, work_order) do
    scope = socket.assigns.current_scope

    assign(socket,
      work_order: work_order,
      costs: Maintenance.Costs.breakdown(work_order, scope: scope),
      members: FleetmsWeb.ActivityLog.member_names(scope),
      page_title: "##{work_order.work_order_number}",
      can_update: Scope.has_permission?(scope, :update_work_order),
      can_delete: Scope.has_permission?(scope, :delete_work_order)
    )
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
      <style>
        @media print {
          body * { visibility: hidden !important; }
          #wo-document, #wo-document * { visibility: visible !important; }
          #wo-document {
            position: absolute; inset: 0; margin: 0; width: 100%;
            border: none !important; box-shadow: none !important;
          }
        }
      </style>

      <.breadcrumbs items={[
        %{label: gettext("Dashboard"), path: ~p"/o/#{org(assigns)}", icon: "fa-house"},
        %{label: gettext("Work Orders"), path: ~p"/o/#{org(assigns)}/work-orders"},
        %{label: "##{@work_order.work_order_number}"}
      ]} />

      <div class="mt-4 flex flex-col gap-4 rounded-base border border-default bg-white p-4 shadow-sm dark:bg-gray-800 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <h1 class="text-xl font-bold text-heading">
            <span class="text-body">#{@work_order.work_order_number}</span> {vehicle_name(@work_order)}
          </h1>
          <div class="mt-2 flex flex-wrap items-center gap-2">
            <.badge color={status_color(@work_order.status)}>
              {humanize(@work_order.status)}
            </.badge>
            <span :if={@work_order.repair_category} class="text-sm text-body">
              {humanize(@work_order.repair_category)}
            </span>
          </div>
        </div>

        <div class="flex flex-wrap items-center gap-2">
          <.button
            :if={@can_update and @work_order.status == :open}
            variant="success"
            phx-click="start"
          >
            <.icon name="fa-play" class="me-2" /> {gettext("Start")}
          </.button>
          <.button
            :if={@can_update and @work_order.status in [:open, :in_progress]}
            variant="success"
            phx-click="complete"
            data-confirm={gettext("Mark this work order completed?")}
          >
            <.icon name="fa-circle-check" class="me-2" /> {gettext("Complete")}
          </.button>
          <.button
            :if={@can_update and @work_order.status == :completed}
            variant="secondary"
            phx-click="reopen"
            data-confirm={gettext("Reopen this work order?")}
          >
            <.icon name="fa-rotate-left" class="me-2" /> {gettext("Reopen")}
          </.button>
          <.button
            :if={@can_update}
            navigate={~p"/o/#{org(assigns)}/work-orders/#{@work_order.id}/edit"}
          >
            <.icon name="fa-pen-to-square" class="me-2" /> {gettext("Edit")}
          </.button>
        </div>
      </div>

      <div class="mt-4 rounded-base border border-default bg-white px-4 shadow-sm dark:bg-gray-800">
        <.tabs active={@active_tab} on_select="select-tab">
          <:tab name="overview" label={gettext("Overview")} icon="fa-list-check">
            <.list>
              <:item title={gettext("Status")}>{humanize(@work_order.status)}</:item>
              <:item title={gettext("Vehicle")}>{vehicle_name(@work_order)}</:item>
              <:item title={gettext("Assigned to")}>{person_name(@work_order.assigned_to)}</:item>
              <:item title={gettext("Issued by")}>{person_name(@work_order.issued_by)}</:item>
              <:item title={gettext("Repair category")}>
                {present(humanize(@work_order.repair_category))}
              </:item>
              <:item title={gettext("Issued")}>
                {Format.datetime(@work_order.issued_at, org(assigns))}
              </:item>
              <:item :if={@work_order.started_at} title={gettext("Started")}>
                {Format.datetime(@work_order.started_at, org(assigns))}
              </:item>
              <:item :if={@work_order.completed_at} title={gettext("Completed")}>
                {Format.datetime(@work_order.completed_at, org(assigns))}
              </:item>
              <:item title={gettext("Odometer")}>
                {Format.distance(@work_order.mileage, org(assigns))}
              </:item>
              <:item title={gettext("Engine hours")}>{present(@work_order.hours)}</:item>
              <:item :if={@work_order.tags != []} title={gettext("Tags")}>
                <.tag_list tags={@work_order.tags} />
              </:item>
            </.list>

            <div :if={present?(@work_order.description)} class="mt-6">
              <h2 class="mb-2 text-sm font-semibold uppercase text-heading">
                {gettext("Description")}
              </h2>
              <p class="whitespace-pre-wrap text-sm text-body">{@work_order.description}</p>
            </div>

            <div class="mt-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
              <.cost_tile label={gettext("Parts")} money={@costs.parts} />
              <.cost_tile label={gettext("Technician labour")} money={@costs.technician_labor} />
              <.cost_tile label={gettext("Vendor labour")} money={@costs.vendor_labor} />
              <.cost_tile label={gettext("Total")} money={@costs.total} emphasis />
            </div>

            <div :if={@work_order.issues != []} class="mt-8">
              <h2 class="mb-2 text-sm font-semibold uppercase text-heading">
                {gettext("Issues addressed")}
              </h2>
              <ul class="space-y-1 text-sm">
                <li :for={issue <- @work_order.issues} class="flex items-center gap-2">
                  <.link
                    navigate={~p"/o/#{org(assigns)}/issues/#{issue.id}"}
                    class="text-brand hover:underline"
                  >
                    #{issue.issue_number} {issue.title}
                  </.link>
                  <.badge color={issue_color(issue.status)} size="sm">
                    {humanize(issue.status)}
                  </.badge>
                </li>
              </ul>
            </div>

            <h2 class="mb-2 mt-8 text-sm font-semibold uppercase text-heading">
              {gettext("Service tasks")}
            </h2>
            <p
              :if={@work_order.work_order_service_tasks == []}
              class="rounded-base border border-dashed border-default p-6 text-center text-sm text-body"
            >
              {gettext("No service tasks recorded on this work order.")}
            </p>
            <div
              :for={task <- @work_order.work_order_service_tasks}
              class="mb-4 rounded-base border border-default p-4"
            >
              <h3 class="font-semibold text-heading">{task_name(task)}</h3>

              <div :if={task.work_order_service_task_parts != []} class="mt-3">
                <p class="mb-1 text-xs font-semibold uppercase text-body">{gettext("Parts")}</p>
                <ul class="space-y-1 text-sm text-body">
                  <li :for={part <- task.work_order_service_task_parts} class="flex justify-between">
                    <span>{part_name(part)} × {fmt_num(part.quantity)}</span>
                    <span>{money(part.subtotal)}</span>
                  </li>
                </ul>
              </div>

              <div :if={task.labor_items != []} class="mt-3">
                <p class="mb-1 text-xs font-semibold uppercase text-body">{gettext("Labour")}</p>
                <ul class="space-y-1 text-sm text-body">
                  <li :for={labor <- task.labor_items} class="flex justify-between">
                    <span>{labor_label(labor)}</span>
                    <span>{money(labor.subtotal)}</span>
                  </li>
                </ul>
              </div>
            </div>
          </:tab>

          <:tab name="document" label={gettext("Print view")} icon="fa-file-lines">
            <div class="mb-4 flex justify-end">
              <.button id="print-work-order" phx-hook="PrintButton" type="button" variant="secondary">
                <.icon name="fa-print" class="me-2" /> {gettext("Print")}
              </.button>
            </div>

            <div
              id="wo-document"
              class="mx-auto max-w-3xl rounded-base border border-default bg-white p-8 text-gray-900 shadow-sm"
            >
              <div class="flex items-start justify-between border-b border-gray-200 pb-4">
                <div>
                  <p class="text-lg font-bold">{Fleetms.Scope.workspace_name(@current_scope)}</p>
                  <p class="text-sm text-gray-500">{gettext("Work Order")}</p>
                </div>
                <div class="text-right">
                  <p class="text-2xl font-bold">#{@work_order.work_order_number}</p>
                  <p class="text-sm text-gray-500">{humanize(@work_order.status)}</p>
                </div>
              </div>

              <div class="mt-4 grid grid-cols-2 gap-4 text-sm">
                <div>
                  <p class="text-gray-500">{gettext("Vehicle")}</p>
                  <p class="font-medium">{vehicle_name(@work_order)}</p>
                </div>
                <div>
                  <p class="text-gray-500">{gettext("Assigned to")}</p>
                  <p class="font-medium">{person_name(@work_order.assigned_to)}</p>
                </div>
                <div>
                  <p class="text-gray-500">{gettext("Issued")}</p>
                  <p class="font-medium">{Format.datetime(@work_order.issued_at, org(assigns))}</p>
                </div>
                <div>
                  <p class="text-gray-500">{gettext("Completed")}</p>
                  <p class="font-medium">{Format.datetime(@work_order.completed_at, org(assigns))}</p>
                </div>
              </div>

              <table class="mt-6 w-full text-left text-sm">
                <thead class="border-b border-gray-300 text-xs uppercase text-gray-500">
                  <tr>
                    <th class="py-2">{gettext("Item")}</th>
                    <th class="py-2 text-right">{gettext("Qty / Hrs")}</th>
                    <th class="py-2 text-right">{gettext("Amount")}</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for task <- @work_order.work_order_service_tasks do %>
                    <tr class="border-b border-gray-100">
                      <td class="py-2 font-semibold" colspan="3">{task_name(task)}</td>
                    </tr>
                    <tr
                      :for={part <- task.work_order_service_task_parts}
                      class="border-b border-gray-100"
                    >
                      <td class="py-1 pl-4">{part_name(part)}</td>
                      <td class="py-1 text-right">{fmt_num(part.quantity)}</td>
                      <td class="py-1 text-right">{money(part.subtotal)}</td>
                    </tr>
                    <tr :for={labor <- task.labor_items} class="border-b border-gray-100">
                      <td class="py-1 pl-4">{labor_label(labor)}</td>
                      <td class="py-1 text-right">{present(fmt_num(labor.hours))}</td>
                      <td class="py-1 text-right">{money(labor.subtotal)}</td>
                    </tr>
                  <% end %>
                </tbody>
              </table>

              <div class="mt-6 flex justify-end">
                <div class="w-64 space-y-1 text-sm">
                  <div class="flex justify-between">
                    <span class="text-gray-500">{gettext("Parts")}</span>
                    <span>{money_list(@costs.parts)}</span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-500">{gettext("Labour")}</span>
                    <span>{money_list(@costs.labor)}</span>
                  </div>
                  <div class="flex justify-between border-t border-gray-300 pt-1 font-bold">
                    <span>{gettext("Total")}</span>
                    <span>{money_list(@costs.total)}</span>
                  </div>
                </div>
              </div>

              <div class="mt-12 grid grid-cols-2 gap-8 text-sm">
                <div>
                  <div class="border-t border-gray-400 pt-1 text-gray-500">
                    {gettext("Technician signature")}
                  </div>
                </div>
                <div>
                  <div class="border-t border-gray-400 pt-1 text-gray-500">
                    {gettext("Approved by")}
                  </div>
                </div>
              </div>
            </div>
          </:tab>

          <:tab name="photos" label={gettext("Photos")} icon="fa-image">
            <div
              :if={@work_order.photos != []}
              class="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4"
            >
              <div :for={photo <- @work_order.photos} class="group relative">
                <a href={storage_url(photo.image_key)} target="_blank" rel="noopener">
                  <img
                    src={storage_url(photo.thumbnail_key)}
                    alt={photo.caption || "Work order photo"}
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
            <p :if={@work_order.photos == []} class="text-body">{gettext("No photos yet.")}</p>

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
            <ul :if={@work_order.documents != []} class="divide-y divide-default">
              <li :for={doc <- @work_order.documents} class="flex items-center gap-3 py-3">
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
            <p :if={@work_order.documents == []} class="text-body">
              {gettext("No documents yet.")}
            </p>

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
              id={"comments-#{@work_order.id}"}
              scope={@current_scope}
              parent_key={:work_order_id}
              parent_id={@work_order.id}
            />
          </:tab>

          <:tab name="history" label={gettext("History")} icon="fa-clock-rotate-left">
            <FleetmsWeb.ActivityLog.timeline
              kind={:work_order}
              versions={@work_order.paper_trail_versions}
              members={@members}
            />
          </:tab>
        </.tabs>
      </div>
    </Layouts.app>
    """
  end

  attr :label, :string, required: true
  attr :money, :list, required: true
  attr :emphasis, :boolean, default: false

  defp cost_tile(assigns) do
    ~H"""
    <div class={[
      "rounded-base border p-3",
      @emphasis && "border-brand bg-brand/5",
      !@emphasis && "border-default"
    ]}>
      <p class="text-xs uppercase text-body">{@label}</p>
      <p class={["mt-1 font-semibold", @emphasis && "text-brand", !@emphasis && "text-heading"]}>
        {money_list(@money)}
      </p>
    </div>
    """
  end

  @impl true
  def handle_event("select-tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_event("start", _params, socket), do: transition(socket, :start_work_order)
  def handle_event("complete", _params, socket), do: transition(socket, :complete_work_order)
  def handle_event("reopen", _params, socket), do: transition(socket, :reopen_work_order)

  def handle_event("validate-upload", _params, socket), do: {:noreply, socket}

  def handle_event("cancel-photo", %{"ref" => ref}, socket),
    do: {:noreply, cancel_upload(socket, :photos, ref)}

  def handle_event("cancel-document", %{"ref" => ref}, socket),
    do: {:noreply, cancel_upload(socket, :documents, ref)}

  def handle_event("save-photos", _params, socket) do
    scope = socket.assigns.current_scope
    work_order = socket.assigns.work_order

    results =
      consume_uploaded_entries(socket, :photos, fn %{path: path}, _entry ->
        {:ok,
         Maintenance.upload_work_order_photo(
           %{work_order_id: work_order.id, source_path: path},
           scope: scope
         )}
      end)

    {:noreply, finish_upload(socket, results, gettext("Photos uploaded."))}
  end

  def handle_event("save-documents", _params, socket) do
    scope = socket.assigns.current_scope
    work_order = socket.assigns.work_order

    results =
      consume_uploaded_entries(socket, :documents, fn %{path: path}, entry ->
        {:ok,
         Maintenance.upload_work_order_document(
           %{
             work_order_id: work_order.id,
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
    delete_child(
      socket,
      socket.assigns.work_order.photos,
      id,
      &Maintenance.delete_work_order_photo/2
    )
  end

  def handle_event("delete-document", %{"id" => id}, socket) do
    delete_child(
      socket,
      socket.assigns.work_order.documents,
      id,
      &Maintenance.delete_work_order_document/2
    )
  end

  defp transition(socket, fun) do
    scope = socket.assigns.current_scope

    case apply(Maintenance, fun, [socket.assigns.work_order, [scope: scope]]) do
      {:ok, _updated} ->
        {:ok, reloaded} =
          Maintenance.get_work_order(socket.assigns.work_order.id, scope: scope, load: @loads)

        {:noreply,
         socket
         |> assign_work_order(reloaded)
         |> put_flash(:info, gettext("Work order updated."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("That action isn't allowed right now."))}
    end
  end

  # --- uploads ---

  # A drag-and-drop upload form with per-entry progress/preview. Mirrors the panel
  # in issue/vehicle detail pages (a shared extraction is a noted follow-up).
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
          <progress value={entry.progress} max="100" class="h-1.5 w-full">
            {entry.progress}%
          </progress>
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
    {:ok, work_order} =
      Maintenance.get_work_order(socket.assigns.work_order.id,
        scope: socket.assigns.current_scope,
        load: @loads
      )

    assign_work_order(socket, work_order)
  end

  defp storage_url(nil), do: nil
  defp storage_url(key), do: Fleetms.Storage.url(key)

  defp upload_error(:too_large), do: gettext("File is too large.")
  defp upload_error(:too_many_files), do: gettext("Too many files.")
  defp upload_error(:not_accepted), do: gettext("That file type isn't allowed.")
  defp upload_error(_), do: gettext("Invalid file.")

  defp humanize_bytes(nil), do: ""
  defp humanize_bytes(bytes) when bytes < 1_024, do: "#{bytes} B"
  defp humanize_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1_024, 1)} KB"
  defp humanize_bytes(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  # --- display helpers ---

  defp status_color(:open), do: "info"
  defp status_color(:in_progress), do: "warning"
  defp status_color(:completed), do: "success"

  defp issue_color(:open), do: "info"
  defp issue_color(:resolved), do: "success"
  defp issue_color(:closed), do: "gray"

  defp vehicle_name(%{vehicle: %{name: name}}), do: name
  defp vehicle_name(_), do: "—"

  # Prefer the snapshot frozen at completion; fall back to the live part while open.
  defp part_name(%{part_name: name}) when is_binary(name), do: name
  defp part_name(%{part_name: nil, part_number: number}) when is_binary(number), do: number
  defp part_name(%{part: %{name: nil, part_number: number}}), do: number
  defp part_name(%{part: %{name: name}}), do: name
  defp part_name(_), do: "—"

  # Same idea for the service-task line: snapshot if frozen, else the live aggregate.
  defp task_name(%{service_task_name_snapshot: name}) when is_binary(name), do: name
  defp task_name(%{service_task_name: name}) when is_binary(name), do: name
  defp task_name(_), do: "—"

  defp labor_label(%{labor_type: :vendor, vendor: %{name: name}}),
    do: gettext("Vendor: %{name}", name: name)

  defp labor_label(%{labor_type: :vendor}), do: gettext("Vendor labour")
  defp labor_label(%{labor_type: :technician} = labor), do: person_name(labor.technician)
  defp labor_label(_), do: gettext("Labour")

  defp money(nil), do: "—"
  defp money(%Money{} = m), do: Money.to_string!(m)

  defp money_list([]), do: "—"
  defp money_list(list), do: Enum.map_join(list, ", ", &Money.to_string!/1)

  defp fmt_num(nil), do: nil
  defp fmt_num(%Decimal{} = d), do: d |> Decimal.normalize() |> Decimal.to_string(:normal)

  defp person_name(%{profile: %{first_name: first, last_name: last}} = user) do
    case String.trim("#{first} #{last}") do
      "" -> to_string(user.email)
      name -> name
    end
  end

  defp person_name(%{email: email}), do: to_string(email)
  defp person_name(_), do: "—"

  defp humanize(nil), do: nil

  defp humanize(value),
    do: value |> to_string() |> String.replace("_", " ") |> String.capitalize()

  defp present(nil), do: "—"
  defp present(""), do: "—"
  defp present(value), do: value

  defp present?(value), do: value not in [nil, ""]

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
