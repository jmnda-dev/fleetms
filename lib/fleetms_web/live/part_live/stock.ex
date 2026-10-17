defmodule FleetmsWeb.PartLive.Stock do
  @moduledoc """
  Manage a part's stock across inventory locations.

  Lists the part's per-location quantities (`PartStock` rows) with receive/consume
  (the atomic `adjust` action) and remove, plus an "add stock at a location" form
  for locations the part isn't stocked at yet. The part's total on-hand and status
  are derived, so they refresh after every change.
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Inventory
  alias Fleetms.Scope

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, active_link: :inventory)}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    scope = socket.assigns.current_scope

    case Inventory.get_part(id, scope: scope) do
      {:ok, part} ->
        can_view_wo = Fleetms.Scope.has_permission?(scope, :view_work_orders)

        {:noreply,
         socket
         |> assign(:page_title, gettext("Stock — %{part}", part: part.part_number))
         |> assign(:can_manage, can_manage?(scope))
         |> assign(:can_view_work_orders, can_view_wo)
         |> assign(
           :usage,
           if(can_view_wo, do: Fleetms.Inventory.PartUsage.for_part(scope, id), else: [])
         )
         |> assign(:part, part)
         |> load_stock(scope, part)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("That part could not be found."))
         |> push_navigate(to: ~p"/o/#{org(socket)}/parts")}
    end
  end

  # Reload the part (for total_stock/status), its stock rows, and which locations
  # are still free to add.
  defp load_stock(socket, scope, part) do
    part = Inventory.get_part!(part.id, scope: scope)
    stocks = Inventory.list_part_stocks!(part.id, scope: scope)
    all_locations = Inventory.list_inventory_locations!(%{}, scope: scope)

    used = MapSet.new(stocks, & &1.inventory_location_id)
    available = Enum.reject(all_locations, &MapSet.member?(used, &1.id))

    assign(socket,
      part: part,
      stocks: stocks,
      available_locations: available,
      all_locations: all_locations
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
      <.breadcrumbs items={[
        %{label: gettext("Dashboard"), path: ~p"/o/#{org(assigns)}", icon: "fa-house"},
        %{label: gettext("Parts"), path: ~p"/o/#{org(assigns)}/parts"},
        %{label: @part.part_number, path: ~p"/o/#{org(assigns)}/parts/#{@part.id}/edit"},
        %{label: gettext("Stock")}
      ]} />

      <div class="mt-4 flex flex-col gap-4 rounded-base border border-default bg-white p-4 shadow-sm dark:bg-gray-800 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 class="text-xl font-bold text-heading">
            {@part.part_number}
            <span :if={@part.name} class="font-normal text-body">· {@part.name}</span>
          </h2>
          <p class="mt-1 flex items-center gap-2 text-sm text-body">
            {gettext("On hand:")}
            <span class="font-semibold text-heading">{fmt_num(@part.total_stock)}</span>
            <.badge color={status_color(@part.stock_status)}>{@part.stock_status}</.badge>
          </p>
        </div>
        <.button variant="secondary" navigate={~p"/o/#{org(assigns)}/parts"}>
          <.icon name="fa-arrow-left" class="me-2" /> {gettext("Back to parts")}
        </.button>
      </div>

      <div class="mt-4 rounded-base border border-default bg-white shadow-sm dark:bg-gray-800">
        <div class="overflow-x-auto">
          <table class="w-full text-left text-sm text-body">
            <thead class="bg-gray-50 text-xs uppercase text-heading dark:bg-gray-700">
              <tr>
                <th class="px-4 py-3 font-semibold">{gettext("Location")}</th>
                <th class="px-4 py-3 font-semibold">{gettext("Quantity")}</th>
                <th :if={@can_manage} class="px-4 py-3 font-semibold">{gettext("Adjust")}</th>
                <th :if={@can_manage} class="px-4 py-3 text-right font-semibold">
                  <span class="sr-only">{gettext("Actions")}</span>
                </th>
              </tr>
            </thead>
            <tbody>
              <tr :for={stock <- @stocks} class="border-t border-default">
                <td class="whitespace-nowrap px-4 py-3 font-medium text-heading">
                  {stock.inventory_location.name}
                </td>
                <td class="whitespace-nowrap px-4 py-3 text-heading">{fmt_num(stock.quantity)}</td>
                <td :if={@can_manage} class="px-4 py-3">
                  <form phx-submit="adjust" class="flex items-center gap-2">
                    <input type="hidden" name="stock_id" value={stock.id} />
                    <input
                      type="number"
                      name="amount"
                      step="0.01"
                      min="0"
                      placeholder="0"
                      class="w-24 rounded-base border border-default-medium bg-neutral-secondary-medium px-2 py-1.5 text-sm text-heading focus:border-brand focus:ring-brand"
                    />
                    <button
                      type="submit"
                      name="action"
                      value="receive"
                      class="rounded-base bg-success-soft px-2.5 py-1.5 text-xs font-medium text-fg-success hover:bg-success-softer"
                    >
                      <.icon name="fa-plus" /> {gettext("Receive")}
                    </button>
                    <button
                      type="submit"
                      name="action"
                      value="consume"
                      class="rounded-base bg-danger-soft px-2.5 py-1.5 text-xs font-medium text-fg-danger hover:bg-danger-softer"
                    >
                      <.icon name="fa-minus" /> {gettext("Consume")}
                    </button>
                  </form>
                </td>
                <td :if={@can_manage} class="px-4 py-3 text-right">
                  <.button
                    size="xs"
                    variant="danger"
                    phx-click="remove-stock"
                    phx-value-id={stock.id}
                    data-confirm={gettext("Remove this location's stock record?")}
                  >
                    {gettext("Remove")}
                  </.button>
                </td>
              </tr>
              <tr :if={@stocks == []}>
                <td colspan="4" class="px-4 py-10 text-center text-body">
                  {gettext("This part isn't stocked at any location yet.")}
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div
          :if={@can_manage and @available_locations != []}
          class="border-t border-default bg-gray-50 p-4 dark:bg-gray-700/40"
        >
          <h3 class="mb-3 text-sm font-semibold uppercase text-heading">
            {gettext("Add stock at a location")}
          </h3>
          <form phx-submit="add-stock" class="flex flex-col gap-3 sm:flex-row sm:items-end">
            <div class="sm:w-64">
              <label class="mb-1 block text-sm font-medium text-heading">{gettext("Location")}</label>
              <select
                name="location_id"
                required
                class="block w-full rounded-base border border-default-medium bg-white px-3 py-2 text-sm text-heading focus:border-brand focus:ring-brand dark:bg-gray-800"
              >
                <option value="">{gettext("Select a location")}</option>
                {Phoenix.HTML.Form.options_for_select(
                  Enum.map(@available_locations, &{&1.name, &1.id}),
                  nil
                )}
              </select>
            </div>
            <div class="sm:w-40">
              <label class="mb-1 block text-sm font-medium text-heading">{gettext("Quantity")}</label>
              <input
                type="number"
                name="quantity"
                step="0.01"
                min="0"
                value="0"
                class="block w-full rounded-base border border-default-medium bg-white px-3 py-2 text-sm text-heading focus:border-brand focus:ring-brand dark:bg-gray-800"
              />
            </div>
            <.button type="submit">{gettext("Add")}</.button>
          </form>
        </div>

        <div
          :if={@can_manage and transferable?(@stocks) and length(@all_locations) > 1}
          class="border-t border-default p-4"
        >
          <h3 class="mb-3 text-sm font-semibold uppercase text-heading">
            {gettext("Transfer stock")}
          </h3>
          <form phx-submit="transfer" class="flex flex-col gap-3 sm:flex-row sm:items-end">
            <div class="sm:w-56">
              <label class="mb-1 block text-sm font-medium text-heading">{gettext("From")}</label>
              <select
                name="from_id"
                required
                class="block w-full rounded-base border border-default-medium bg-white px-3 py-2 text-sm text-heading focus:border-brand focus:ring-brand dark:bg-gray-800"
              >
                <option
                  :for={s <- @stocks}
                  :if={Decimal.gt?(s.quantity, 0)}
                  value={s.id}
                >
                  {s.inventory_location.name} ({fmt_num(s.quantity)})
                </option>
              </select>
            </div>
            <div class="sm:w-56">
              <label class="mb-1 block text-sm font-medium text-heading">{gettext("To")}</label>
              <select
                name="to_location_id"
                required
                class="block w-full rounded-base border border-default-medium bg-white px-3 py-2 text-sm text-heading focus:border-brand focus:ring-brand dark:bg-gray-800"
              >
                <option value="">{gettext("Select a location")}</option>
                {Phoenix.HTML.Form.options_for_select(
                  Enum.map(@all_locations, &{&1.name, &1.id}),
                  nil
                )}
              </select>
            </div>
            <div class="sm:w-32">
              <label class="mb-1 block text-sm font-medium text-heading">{gettext("Quantity")}</label>
              <input
                type="number"
                name="amount"
                step="0.01"
                min="0"
                class="block w-full rounded-base border border-default-medium bg-white px-3 py-2 text-sm text-heading focus:border-brand focus:ring-brand dark:bg-gray-800"
              />
            </div>
            <.button type="submit" variant="secondary">
              <.icon name="fa-right-left" class="me-1" /> {gettext("Transfer")}
            </.button>
          </form>
        </div>
      </div>

      <div
        :if={@can_view_work_orders}
        class="mt-6 rounded-base border border-default bg-white shadow-sm dark:bg-gray-800"
      >
        <div class="border-b border-default px-4 py-3">
          <h3 class="text-sm font-semibold uppercase text-heading">{gettext("Usage history")}</h3>
          <p class="text-xs text-body">
            {gettext("Where this part has been used on work orders.")}
          </p>
        </div>

        <table :if={@usage != []} class="w-full text-left text-sm text-body">
          <thead class="bg-gray-50 text-xs uppercase text-heading dark:bg-gray-700">
            <tr>
              <th class="px-4 py-3 font-semibold">{gettext("Work order")}</th>
              <th class="px-4 py-3 font-semibold">{gettext("Date")}</th>
              <th class="px-4 py-3 text-right font-semibold">{gettext("Quantity")}</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={u <- @usage} class="border-t border-default">
              <td class="px-4 py-3">
                <.link
                  :if={u.work_order_id}
                  navigate={~p"/o/#{org(assigns)}/work-orders/#{u.work_order_id}"}
                  class="font-medium text-brand hover:underline"
                >
                  WO #{u.work_order_number}
                </.link>
              </td>
              <td class="whitespace-nowrap px-4 py-3">
                {u.date && Fleetms.Format.date(u.date, org(assigns))}
              </td>
              <td class="px-4 py-3 text-right font-medium text-heading">{fmt_num(u.quantity)}</td>
            </tr>
          </tbody>
        </table>

        <p :if={@usage == []} class="px-4 py-6 text-center text-sm text-body">
          {gettext("This part hasn't been used on any work orders yet.")}
        </p>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("add-stock", %{"location_id" => location_id, "quantity" => quantity}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, qty} <- to_decimal(quantity),
         {:ok, _stock} <-
           Inventory.set_part_stock(
             %{
               part_id: socket.assigns.part.id,
               inventory_location_id: location_id,
               quantity: qty
             },
             scope: scope
           ) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Stock added."))
       |> load_stock(scope, socket.assigns.part)}
    else
      _ ->
        {:noreply, put_flash(socket, :error, gettext("Could not add stock. Check the amount."))}
    end
  end

  def handle_event("adjust", %{"stock_id" => id, "amount" => amount, "action" => action}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, amt} <- to_decimal(amount),
         true <- Decimal.gt?(amt, 0) or {:error, :non_positive},
         delta = signed_delta(action, amt),
         {:ok, stock} <- Inventory.get_part_stock(id, scope: scope),
         {:ok, _} <- Inventory.adjust_part_stock(stock, %{delta: delta}, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, adjust_message(action))
       |> load_stock(scope, socket.assigns.part)}
    else
      {:error, :non_positive} ->
        {:noreply, put_flash(socket, :error, gettext("Enter an amount greater than zero."))}

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Couldn't adjust — a consume can't take stock below zero."))
         |> load_stock(scope, socket.assigns.part)}
    end
  end

  def handle_event(
        "transfer",
        %{"from_id" => from_id, "to_location_id" => to_loc, "amount" => amount},
        socket
      ) do
    scope = socket.assigns.current_scope
    part = socket.assigns.part

    with {:ok, amt} <- to_decimal(amount),
         true <- Decimal.gt?(amt, 0) or {:error, :non_positive},
         {:ok, from} <- Inventory.get_part_stock(from_id, scope: scope),
         true <- from.inventory_location_id != to_loc or {:error, :same_location},
         true <- not Decimal.lt?(from.quantity, amt) or {:error, :insufficient},
         {:ok, _} <- receive_at(scope, part, to_loc, amt),
         {:ok, _} <-
           Inventory.adjust_part_stock(from, %{delta: Decimal.negate(amt)}, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Stock transferred."))
       |> load_stock(scope, part)}
    else
      {:error, :non_positive} ->
        {:noreply, put_flash(socket, :error, gettext("Enter an amount greater than zero."))}

      {:error, :same_location} ->
        {:noreply, put_flash(socket, :error, gettext("Pick two different locations."))}

      {:error, :insufficient} ->
        {:noreply, put_flash(socket, :error, gettext("The source doesn't have that much stock."))}

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Couldn't transfer that stock."))
         |> load_stock(scope, part)}
    end
  end

  def handle_event("remove-stock", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, stock} <- Inventory.get_part_stock(id, scope: scope),
         :ok <- Inventory.delete_part_stock(stock, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Stock record removed."))
       |> load_stock(scope, socket.assigns.part)}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not remove that record."))}
    end
  end

  defp signed_delta("consume", amount), do: Decimal.negate(amount)
  defp signed_delta(_receive, amount), do: amount

  defp adjust_message("consume"), do: gettext("Stock consumed.")
  defp adjust_message(_), do: gettext("Stock received.")

  defp to_decimal(value) do
    {:ok, Decimal.new(value)}
  rescue
    _ -> :error
  end

  defp can_manage?(scope) do
    Scope.has_permission?(scope, :update_part) or Scope.has_permission?(scope, :create_part)
  end

  defp status_color("In stock"), do: "success"
  defp status_color("Low"), do: "warning"
  defp status_color("Out of stock"), do: "danger"
  defp status_color(_), do: "gray"

  defp fmt_num(nil), do: "0"
  # `:normal` avoids scientific notation (normalize turns 50 into 5E+1 otherwise).
  defp fmt_num(%Decimal{} = d), do: d |> Decimal.normalize() |> Decimal.to_string(:normal)

  # Adds `amt` to the destination location: bumps the existing stock row if there
  # is one, otherwise creates it.
  defp receive_at(scope, part, location_id, amt) do
    existing =
      Inventory.list_part_stocks!(part.id, scope: scope)
      |> Enum.find(&(&1.inventory_location_id == location_id))

    if existing do
      Inventory.adjust_part_stock(existing, %{delta: amt}, scope: scope)
    else
      Inventory.set_part_stock(
        %{part_id: part.id, inventory_location_id: location_id, quantity: amt},
        scope: scope
      )
    end
  end

  defp transferable?(stocks), do: Enum.any?(stocks, &Decimal.gt?(&1.quantity, 0))

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
