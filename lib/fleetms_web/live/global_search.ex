defmodule FleetmsWeb.GlobalSearch do
  @moduledoc """
  The ⌘K command palette. Rendered once in the org app shell, it lets the user
  jump to a vehicle, issue or work order from anywhere.

  Opening, closing and arrow-key navigation are handled client-side by the
  `CommandPalette` JS hook (no round-trip); typing runs `Fleetms.Search` through
  the component's own `phx-target`, so no host LiveView needs to know about it.
  """
  use FleetmsWeb, :live_component

  alias Fleetms.Search

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:query, fn -> "" end)
     |> assign_new(:groups, fn -> [] end)}
  end

  @impl true
  def handle_event("cmdk_search", %{"q" => query}, socket) do
    {:noreply,
     assign(socket, query: query, groups: Search.run(query, socket.assigns.current_scope))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="global-search-overlay"
      phx-hook="CommandPalette"
      class="fixed inset-0 z-50 hidden"
      role="dialog"
      aria-modal="true"
      aria-label={gettext("Search")}
    >
      <div data-cmdk-backdrop class="fixed inset-0 bg-gray-900/50 backdrop-blur-sm"></div>

      <div class="fixed inset-x-0 top-16 mx-auto w-full max-w-xl px-4">
        <div class="overflow-hidden rounded-xl border border-default bg-white shadow-2xl dark:bg-gray-800">
          <form phx-change="cmdk_search" phx-submit="cmdk_search" phx-target={@myself}>
            <div class="flex items-center gap-3 border-b border-default px-4">
              <i class="fa-solid fa-magnifying-glass text-gray-400"></i>
              <input
                type="text"
                name="q"
                value={@query}
                data-cmdk-input
                autocomplete="off"
                phx-debounce="150"
                placeholder={gettext("Search vehicles, issues, work orders…")}
                class="w-full border-0 bg-transparent py-3.5 text-sm text-heading placeholder-gray-400 focus:outline-none focus:ring-0"
              />
              <kbd class="hidden rounded border border-default px-1.5 py-0.5 text-xs text-body sm:block">
                Esc
              </kbd>
            </div>
          </form>

          <div class="max-h-80 overflow-y-auto py-2">
            <div :if={@groups == [] and String.trim(@query) != ""} class="px-4 py-8 text-center">
              <i class="fa-solid fa-magnifying-glass mb-2 text-2xl text-gray-300 dark:text-gray-600">
              </i>
              <p class="text-sm text-body">
                {gettext("No matches for \"%{query}\".", query: String.trim(@query))}
              </p>
            </div>

            <p
              :if={@groups == [] and String.trim(@query) == ""}
              class="px-4 py-8 text-center text-sm text-body"
            >
              {gettext("Start typing to search across your fleet.")}
            </p>

            <div :for={group <- @groups} class="mb-1">
              <p class="px-4 py-1.5 text-xs font-semibold uppercase tracking-wide text-gray-400">
                {group_heading(group.type)}
              </p>
              <.link
                :for={item <- group.items}
                data-cmdk-result
                navigate={result_path(@current_scope.organization, group.type, item.id)}
                class="flex items-center gap-3 px-4 py-2 text-sm hover:bg-gray-100 aria-selected:bg-gray-100 dark:hover:bg-gray-700 dark:aria-selected:bg-gray-700"
              >
                <i class={["fa-solid w-4 text-center text-gray-400", group_icon(group.type)]}></i>
                <span class="min-w-0 flex-1">
                  <span class="block truncate font-medium text-heading">{item.primary}</span>
                  <span :if={item.secondary} class="block truncate text-xs text-body">
                    {item.secondary}
                  </span>
                </span>
                <i class="fa-solid fa-arrow-turn-down rotate-90 text-xs text-gray-300 dark:text-gray-600">
                </i>
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp group_heading(:vehicle), do: gettext("Vehicles")
  defp group_heading(:issue), do: gettext("Issues")
  defp group_heading(:work_order), do: gettext("Work orders")

  defp group_icon(:vehicle), do: "fa-car"
  defp group_icon(:issue), do: "fa-triangle-exclamation"
  defp group_icon(:work_order), do: "fa-screwdriver-wrench"

  defp result_path(org, :vehicle, id), do: ~p"/o/#{org}/vehicles/#{id}"
  defp result_path(org, :issue, id), do: ~p"/o/#{org}/issues/#{id}"
  defp result_path(org, :work_order, id), do: ~p"/o/#{org}/work-orders/#{id}"
end
