defmodule FleetmsWeb.VehicleLive.Import do
  @moduledoc """
  Bulk-import vehicles from a CSV file. Upload a file, see a validated preview (which
  rows will import and why any won't), then confirm to create them. Makes and models
  are created by name as needed. See `Fleetms.VehicleManagement.VehicleImport`.
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Scope
  alias Fleetms.VehicleManagement.VehicleImport

  @max_bytes 2_000_000

  # `current_scope` is set by the require_organization on_mount hook during
  # handle_params, so it isn't available in mount/3 — the permission gate lives in
  # handle_params. allow_upload needs no scope, so it stays here.
  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: gettext("Import vehicles"),
       active_link: :vehicles,
       preview: nil,
       result: nil
     )
     |> allow_upload(:csv, accept: ~w(.csv text/csv), max_entries: 1, max_file_size: @max_bytes)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    scope = socket.assigns.current_scope

    if Scope.has_permission?(scope, :create_vehicle) do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> put_flash(:error, gettext("You don't have permission to add vehicles."))
       |> push_navigate(to: ~p"/o/#{scope.organization}/vehicles")}
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
        %{label: gettext("Vehicles"), path: ~p"/o/#{org(assigns)}/vehicles"},
        %{label: gettext("Import")}
      ]} />

      <.header>
        {gettext("Import vehicles")}
        <:subtitle>{gettext("Add your whole fleet at once from a spreadsheet.")}</:subtitle>
        <:actions>
          <.button variant="secondary" navigate={~p"/o/#{org(assigns)}/vehicles"}>
            <.icon name="fa-arrow-left-long" class="me-2" /> {gettext("Back to vehicles")}
          </.button>
        </:actions>
      </.header>

      <div class="mt-6 max-w-4xl space-y-6">
        <%!-- Step 1: instructions + upload --%>
        <section
          :if={is_nil(@result)}
          class="rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800"
        >
          <div class="flex flex-col gap-2 text-sm text-body">
            <p>
              {gettext(
                "Upload a CSV with a header row. The columns %{required} are required; everything else is optional.",
                required: "name, type"
              )}
            </p>
            <p>
              <.link
                href={~p"/o/#{org(assigns)}/vehicles/import-template.csv"}
                class="inline-flex items-center gap-1 font-medium text-brand hover:underline"
              >
                <.icon name="fa-file-csv" class="text-xs" /> {gettext("Download a template")}
              </.link>
            </p>
          </div>

          <form id="csv-upload" phx-change="validate" phx-submit="preview" class="mt-4">
            <div
              class="flex flex-col items-center justify-center gap-2 rounded-base border-2 border-dashed border-default-medium p-8 text-center"
              phx-drop-target={@uploads.csv.ref}
            >
              <.icon name="fa-cloud-arrow-up" class="text-2xl text-body" />
              <p class="text-sm text-body">{gettext("Drag a .csv here, or")}</p>
              <.live_file_input upload={@uploads.csv} class="text-sm text-heading" />
            </div>

            <div :for={entry <- @uploads.csv.entries} class="mt-3 flex items-center gap-3 text-sm">
              <span class="text-heading">{entry.client_name}</span>
              <button
                type="button"
                phx-click="cancel"
                phx-value-ref={entry.ref}
                class="text-body hover:text-danger"
              >
                <.icon name="fa-xmark" />
              </button>
              <p :for={err <- upload_errors(@uploads.csv, entry)} class="text-fg-danger-strong">
                {upload_error_to_string(err)}
              </p>
            </div>

            <div class="mt-4">
              <.button type="submit" disabled={@uploads.csv.entries == []}>
                <.icon name="fa-eye" class="me-2" /> {gettext("Preview")}
              </.button>
            </div>
          </form>
        </section>

        <%!-- Step 2: preview --%>
        <section
          :if={@preview && is_nil(@result)}
          class="rounded-base border border-default bg-white shadow-sm dark:bg-gray-800"
        >
          <div class="flex items-center justify-between border-b border-default p-4">
            <div class="text-sm">
              <span class="font-semibold text-heading">
                {gettext("%{ok} ready to import", ok: @preview.ok_count)}
              </span>
              <span :if={@preview.error_count > 0} class="ms-2 text-fg-danger-strong">
                {gettext("%{bad} with problems (skipped)", bad: @preview.error_count)}
              </span>
            </div>
            <.button
              phx-click="import"
              disabled={@preview.ok_count == 0}
              phx-disable-with={gettext("Importing…")}
            >
              <.icon name="fa-file-import" class="me-2" />
              {gettext("Import %{n} vehicles", n: @preview.ok_count)}
            </.button>
          </div>

          <div class="overflow-x-auto">
            <table class="w-full text-left text-sm text-body">
              <thead class="bg-gray-50 text-xs uppercase text-heading dark:bg-gray-700">
                <tr>
                  <th class="px-4 py-3 font-semibold">{gettext("Row")}</th>
                  <th class="px-4 py-3 font-semibold">{gettext("Name")}</th>
                  <th class="px-4 py-3 font-semibold">{gettext("Type")}</th>
                  <th class="px-4 py-3 font-semibold">{gettext("Status / problems")}</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={row <- @preview.rows} class="border-t border-default">
                  <td class="px-4 py-2 text-body">{row.line}</td>
                  <td class="px-4 py-2 font-medium text-heading">{row.name}</td>
                  <td class="px-4 py-2">{row.type && to_string(row.type)}</td>
                  <td class="px-4 py-2">
                    <span
                      :if={row.errors == []}
                      class="inline-flex items-center gap-1 text-fg-success-strong"
                    >
                      <.icon name="fa-circle-check" class="text-xs" /> {gettext("Ready")}
                    </span>
                    <span :if={row.errors != []} class="text-fg-danger-strong">
                      {Enum.join(row.errors, "; ")}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <div class="border-t border-default p-4">
            <.button variant="secondary" phx-click="reset">
              {gettext("Choose a different file")}
            </.button>
          </div>
        </section>

        <%!-- Step 3: result --%>
        <section
          :if={@result}
          class="rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800"
        >
          <div class="flex flex-col items-center gap-3 text-center">
            <span class="flex h-12 w-12 items-center justify-center rounded-full bg-success-soft text-fg-success-strong">
              <.icon name="fa-check" class="text-xl" />
            </span>
            <h2 class="text-lg font-semibold text-heading">
              {gettext("Imported %{n} vehicles", n: @result.created)}
            </h2>
            <p :if={@result.skipped > 0} class="text-sm text-body">
              {gettext("%{n} rows were skipped because of validation problems.", n: @result.skipped)}
            </p>
          </div>

          <div :if={@result.failed != []} class="mt-4">
            <h3 class="mb-2 text-sm font-semibold text-heading">
              {gettext("These rows could not be created:")}
            </h3>
            <ul class="space-y-1 text-sm text-fg-danger-strong">
              <li :for={f <- @result.failed}>
                {gettext("Row %{line} (%{name}): %{error}",
                  line: f.line,
                  name: f.name,
                  error: f.error
                )}
              </li>
            </ul>
          </div>

          <div class="mt-6 flex justify-center gap-3">
            <.button navigate={~p"/o/#{org(assigns)}/vehicles"}>
              <.icon name="fa-truck" class="me-2" /> {gettext("Go to vehicles")}
            </.button>
            <.button variant="secondary" phx-click="reset">
              {gettext("Import another file")}
            </.button>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", _params, socket), do: {:noreply, socket}

  def handle_event("cancel", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :csv, ref)}
  end

  def handle_event("reset", _params, socket) do
    {:noreply, assign(socket, preview: nil, result: nil)}
  end

  def handle_event("preview", _params, socket) do
    content =
      consume_uploaded_entries(socket, :csv, fn %{path: path}, _entry ->
        {:ok, File.read!(path)}
      end)
      |> List.first()

    case content && VehicleImport.preview(content) do
      {:ok, rows} ->
        ok = Enum.count(rows, &(&1.errors == []))

        preview = %{
          rows: rows,
          ok_count: ok,
          error_count: length(rows) - ok
        }

        {:noreply, assign(socket, preview: preview, result: nil)}

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}

      nil ->
        {:noreply, put_flash(socket, :error, gettext("Choose a file first."))}
    end
  end

  def handle_event("import", _params, socket) do
    %{rows: rows} = socket.assigns.preview
    result = VehicleImport.run(socket.assigns.current_scope, rows)

    {:noreply,
     socket
     |> assign(result: result, preview: nil)
     |> put_flash(:info, gettext("Imported %{n} vehicles.", n: result.created))}
  end

  defp upload_error_to_string(:too_large), do: gettext("The file is too large (max 2 MB).")
  defp upload_error_to_string(:not_accepted), do: gettext("Please choose a .csv file.")
  defp upload_error_to_string(:too_many_files), do: gettext("Upload one file at a time.")
  defp upload_error_to_string(_), do: gettext("That file could not be uploaded.")

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
