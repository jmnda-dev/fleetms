defmodule FleetmsWeb.InspectionLive.Show do
  @moduledoc """
  Shows a submitted inspection: its overall result, each item's answer and status
  (grouped by the version's sections), and the list of failures.

  The result section doubles as a printable report: a Print button opens the
  browser dialog, and a scoped `@media print` rule isolates `#inspection-document`
  (with a formal masthead shown only in print) so it prints as a clean sheet.
  """
  use FleetmsWeb, :live_view

  import FleetmsWeb.InspectionLive.Index, only: [result_badge: 1]

  alias Fleetms.Format
  alias Fleetms.Inspections

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, active_link: :inspections)}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    scope = socket.assigns.current_scope

    case Inspections.get_inspection(id, scope: scope) do
      {:ok, inspection} ->
        version = load_version(scope, inspection.inspection_form_version_id)

        {:noreply,
         assign(socket,
           page_title: gettext("Inspection"),
           inspection: inspection,
           version: version,
           answers_by_id: Map.new(inspection.answers, &{&1.item_id, &1})
         )}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("That inspection could not be found."))
         |> push_navigate(to: ~p"/o/#{org(socket)}/inspections")}
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
      <style>
        @media print {
          body * { visibility: hidden !important; }
          #inspection-document, #inspection-document * { visibility: visible !important; }
          #inspection-document {
            position: absolute; inset: 0; margin: 0; width: 100%;
            background: #fff !important; color: #000 !important;
          }
          #inspection-document * { color: #000 !important; background: transparent !important; }
          #inspection-document .print-card {
            box-shadow: none !important; border-color: #ccc !important;
          }
        }
      </style>

      <.breadcrumbs items={[
        %{label: gettext("Dashboard"), path: ~p"/o/#{org(assigns)}", icon: "fa-house"},
        %{label: gettext("Inspections"), path: ~p"/o/#{org(assigns)}/inspections"},
        %{label: @inspection.vehicle.name}
      ]} />

      <.header>
        {@inspection.inspection_form && @inspection.inspection_form.title}
        <:subtitle>
          {@inspection.vehicle.name} · {Format.datetime(@inspection.submitted_at, org(assigns))}
        </:subtitle>
        <:actions>
          <.result_badge result={@inspection.result} failures={@inspection.failure_count} />
          <.button id="print-inspection" phx-hook="PrintButton" type="button" variant="secondary">
            <.icon name="fa-print" class="me-2" /> {gettext("Print")}
          </.button>
        </:actions>
      </.header>

      <div id="inspection-document" class="mt-6 space-y-6">
        <div class="hidden print:block">
          <div class="flex items-start justify-between border-b border-gray-300 pb-3">
            <div>
              <h1 class="text-xl font-bold">{org(assigns).name}</h1>
              <p class="text-sm">
                {@inspection.inspection_form && @inspection.inspection_form.title}
              </p>
            </div>
            <div class="text-right text-sm">
              <p class="font-semibold uppercase">{Phoenix.Naming.humanize(@inspection.result)}</p>
              <p>{Format.datetime(@inspection.submitted_at, org(assigns))}</p>
            </div>
          </div>
          <dl class="mt-3 grid grid-cols-2 gap-x-6 gap-y-1 text-sm">
            <div>
              <dt class="inline font-medium">{gettext("Vehicle")}:</dt>
              <dd class="inline">{@inspection.vehicle.name}</dd>
            </div>
            <div>
              <dt class="inline font-medium">{gettext("Inspector")}:</dt>
              <dd class="inline">{submitter_name(@inspection)}</dd>
            </div>
            <div>
              <dt class="inline font-medium">{gettext("Failures")}:</dt>
              <dd class="inline">{@inspection.failure_count}</dd>
            </div>
            <div :if={@inspection.inspection_form_version}>
              <dt class="inline font-medium">{gettext("Form version")}:</dt>
              <dd class="inline">v{@inspection.inspection_form_version.version_number}</dd>
            </div>
          </dl>
        </div>

        <div
          :if={@inspection.failures != []}
          class="print-card rounded-base border border-red-200 bg-red-50 p-4 dark:border-red-800 dark:bg-red-900/20"
        >
          <h3 class="mb-2 text-sm font-semibold text-red-800 dark:text-red-300">
            {gettext("Failures")}
          </h3>
          <ul class="space-y-1 text-sm text-red-700 dark:text-red-300">
            <li :for={failure <- @inspection.failures}>
              <span class="font-medium">{failure.item_label}</span>
              <span :if={failure.value_snapshot not in [nil, ""]}>— {failure.value_snapshot}</span>
            </li>
          </ul>
        </div>

        <div
          :for={section <- version_sections(@version)}
          class="print-card rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800"
        >
          <h3 :if={section.title} class="mb-4 text-lg font-semibold text-heading">{section.title}</h3>
          <div class="divide-y divide-default">
            <div
              :for={item <- answerable(section.items)}
              class="flex items-start justify-between gap-4 py-3"
            >
              <div class="min-w-0">
                <p class="text-sm font-medium text-heading">{item.label}</p>
                <p
                  :if={answer(@answers_by_id, item).comment not in [nil, ""]}
                  class="text-xs text-body"
                >
                  {answer(@answers_by_id, item).comment}
                </p>
                <div
                  :if={photos(answer(@answers_by_id, item)) != []}
                  class="mt-2 flex flex-wrap gap-2"
                >
                  <a
                    :for={photo <- photos(answer(@answers_by_id, item))}
                    href={Fleetms.Storage.url(photo.image_key)}
                    target="_blank"
                    rel="noopener"
                  >
                    <img
                      src={Fleetms.Storage.url(photo.thumbnail_key)}
                      class="h-16 w-16 rounded-base object-cover"
                      alt={gettext("Inspection photo")}
                    />
                  </a>
                </div>
                <a
                  :if={signature(answer(@answers_by_id, item))}
                  href={Fleetms.Storage.url(signature(answer(@answers_by_id, item)).image_key)}
                  target="_blank"
                  rel="noopener"
                  class="mt-2 inline-block"
                >
                  <img
                    src={Fleetms.Storage.url(signature(answer(@answers_by_id, item)).image_key)}
                    class="h-20 rounded-base border border-default bg-white object-contain"
                    alt={gettext("Signature")}
                  />
                </a>
              </div>
              <div class="flex shrink-0 items-center gap-3">
                <span class="text-sm text-body">{display_value(answer(@answers_by_id, item))}</span>
                <.status_badge status={answer(@answers_by_id, item).status} />
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="mt-4 rounded-base border border-default bg-white p-4 shadow-sm dark:bg-gray-800">
        <h3 class="mb-4 text-sm font-semibold uppercase text-heading">{gettext("Comments")}</h3>
        <.live_component
          module={FleetmsWeb.CommentsSection}
          id={"comments-#{@inspection.id}"}
          scope={@current_scope}
          parent_key={:inspection_id}
          parent_id={@inspection.id}
        />
      </div>
    </Layouts.app>
    """
  end

  attr :status, :atom, required: true

  defp status_badge(assigns) do
    ~H"""
    <span class={[
      "rounded px-2 py-0.5 text-xs font-medium",
      @status == :pass && "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300",
      @status == :fail && "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300",
      @status in [:na, :answered, :skipped] &&
        "bg-gray-100 text-gray-700 dark:bg-gray-700 dark:text-gray-200"
    ]}>
      {Phoenix.Naming.humanize(@status)}
    </span>
    """
  end

  defp version_sections(nil), do: []
  defp version_sections(version), do: version.schema.sections

  # The person who submitted, for the print masthead: their name, else email, else "—".
  defp submitter_name(%{submitted_by: user}) when not is_nil(user) do
    name =
      case user do
        %{profile: %{first_name: first, last_name: last}} ->
          [first, last] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" ")

        _ ->
          ""
      end

    if name == "", do: Map.get(user, :email) || "—", else: name
  end

  defp submitter_name(_inspection), do: "—"

  @answerable ~w(pass_fail number meter single_select multi_select text date photo signature)a
  defp answerable(items), do: Enum.filter(items, &(&1.config.type in @answerable))

  defp answer(by_id, item),
    do:
      Map.get(by_id, item.id) ||
        %{status: :skipped, value: nil, values: nil, comment: nil, photos: []}

  defp photos(%{photos: photos}) when is_list(photos), do: photos
  defp photos(_answer), do: []

  defp signature(%{signature: %{image_key: key} = sig}) when is_binary(key), do: sig
  defp signature(_answer), do: nil

  defp display_value(%{values: values}) when is_list(values) and values != [],
    do: Enum.join(values, ", ")

  defp display_value(%{value: value}) when value not in [nil, ""], do: value
  defp display_value(_answer), do: "—"

  defp load_version(_scope, nil), do: nil

  defp load_version(scope, version_id) do
    case Inspections.get_inspection_form_version(version_id, scope: scope) do
      {:ok, version} -> version
      _ -> nil
    end
  end

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
