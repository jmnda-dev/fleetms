defmodule FleetmsWeb.ThemeLive do
  @moduledoc """
  A dev-only style guide / preview page for the FleetMS theme and CoreComponents.

  Mounted at `/theme` (only when `:dev_routes` is enabled). Use the navbar's
  dark-mode toggle to check every component in both light and dark.
  """
  use FleetmsWeb, :live_view

  @primary_swatches ~w(bg-primary-50 bg-primary-100 bg-primary-200 bg-primary-300 bg-primary-400
                       bg-primary-500 bg-primary-600 bg-primary-700 bg-primary-800 bg-primary-900
                       bg-primary-950)

  @gray_swatches ~w(bg-gray-50 bg-gray-100 bg-gray-200 bg-gray-300 bg-gray-400 bg-gray-500
                    bg-gray-600 bg-gray-700 bg-gray-800 bg-gray-900 bg-gray-950)

  @semantic_swatches ~w(bg-brand bg-success bg-danger bg-warning bg-sky-500)

  @sample_vehicles [
    %{name: "Truck 01", make: "Volvo", status: "Active", color: "success"},
    %{name: "Van 14", make: "Ford", status: "Maintenance", color: "warning"},
    %{name: "Truck 07", make: "Scania", status: "Out-of-Service", color: "danger"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       :form,
       to_form(
         %{
           "name" => "",
           "email" => "",
           "role" => "",
           "bio" => "",
           "purchase_date" => "",
           "description" => ""
         },
         as: :demo
       )
     )
     |> assign(:show_live_modal, false)
     |> assign(:active_tab, "overview")
     |> assign(:vehicles, @sample_vehicles)}
  end

  @impl true
  def handle_event("flash", %{"kind" => kind}, socket) do
    {:noreply,
     put_flash(socket, String.to_existing_atom(kind), "This is a #{kind} flash message.")}
  end

  def handle_event("open-live-modal", _params, socket) do
    {:noreply, assign(socket, :show_live_modal, true)}
  end

  def handle_event("close-live-modal", _params, socket) do
    {:noreply, assign(socket, :show_live_modal, false)}
  end

  def handle_event("select-tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        primary_swatches: @primary_swatches,
        gray_swatches: @gray_swatches,
        semantic_swatches: @semantic_swatches
      )

    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        FleetMS Theme Preview
        <:subtitle>
          Flowbite v4 components on the FleetMS palette — toggle dark mode in the navbar.
        </:subtitle>
      </.header>

      <div class="space-y-12 pb-16">
        <.section title="Palette">
          <p class="mb-2 text-sm font-medium text-heading">Primary (deep navy)</p>
          <div class="flex gap-1">
            <div :for={c <- @primary_swatches} class={["h-12 flex-1 rounded", c]}></div>
          </div>
          <p class="mt-4 mb-2 text-sm font-medium text-heading">Neutral (slate)</p>
          <div class="flex gap-1">
            <div :for={c <- @gray_swatches} class={["h-12 flex-1 rounded border border-default", c]}>
            </div>
          </div>
          <p class="mt-4 mb-2 text-sm font-medium text-heading">
            Semantic (brand / success / danger / warning / info)
          </p>
          <div class="flex gap-1">
            <div :for={c <- @semantic_swatches} class={["h-12 flex-1 rounded", c]}></div>
          </div>
        </.section>

        <.section title="Buttons">
          <div class="flex flex-wrap items-center gap-3">
            <.button>Primary</.button>
            <.button variant="secondary">Secondary</.button>
            <.button variant="success">Success</.button>
            <.button variant="danger">Danger</.button>
            <.button variant="warning">Warning</.button>
            <.button variant="ghost">Ghost</.button>
            <.button disabled>Disabled</.button>
            <.button navigate={~p"/"}>As link</.button>
          </div>
          <div class="mt-4 flex flex-wrap items-center gap-3">
            <.button size="xs">Extra small</.button>
            <.button size="sm">Small</.button>
            <.button size="base">Base</.button>
            <.button size="lg">Large</.button>
            <.button size="xl">Extra large</.button>
          </div>
        </.section>

        <.section title="Badges">
          <div class="flex flex-wrap items-center gap-2">
            <.badge color="brand">Brand</.badge>
            <.badge color="gray">Gray</.badge>
            <.badge color="success">Active</.badge>
            <.badge color="warning">Maintenance</.badge>
            <.badge color="danger">Out-of-Service</.badge>
            <.badge color="info">Info</.badge>
            <.badge color="success" size="base">Large</.badge>
          </div>
        </.section>

        <.section title="Spinners">
          <div class="flex items-center gap-6">
            <.spinner size="sm" />
            <.spinner size="base" />
            <.spinner size="lg" />
          </div>
        </.section>

        <.section title="Alerts (inline)">
          <div class="space-y-3 max-w-xl">
            <div
              class="flex items-start gap-2 p-4 text-sm rounded-base text-fg-brand-strong bg-brand-softer"
              role="alert"
            >
              <.icon name="fa-circle-info" class="mt-0.5 shrink-0" />
              <p>
                <span class="font-medium">Info alert!</span>
                Change a few things up and try submitting again.
              </p>
            </div>
            <div
              class="flex items-start gap-2 p-4 text-sm rounded-base text-fg-success-strong bg-success-soft"
              role="alert"
            >
              <.icon name="fa-circle-check" class="mt-0.5 shrink-0" />
              <p><span class="font-medium">Success alert!</span> Your changes were saved.</p>
            </div>
            <div
              class="flex items-start gap-2 p-4 text-sm rounded-base text-fg-warning bg-warning-soft"
              role="alert"
            >
              <.icon name="fa-triangle-exclamation" class="mt-0.5 shrink-0" />
              <p><span class="font-medium">Warning alert!</span> Service is due soon.</p>
            </div>
            <div
              class="flex items-start gap-2 p-4 text-sm rounded-base text-fg-danger-strong bg-danger-soft"
              role="alert"
            >
              <.icon name="fa-circle-exclamation" class="mt-0.5 shrink-0" />
              <p><span class="font-medium">Danger alert!</span> Something went wrong.</p>
            </div>
          </div>
          <div class="mt-4 flex gap-3">
            <.button size="sm" phx-click="flash" phx-value-kind="info">Trigger info toast</.button>
            <.button size="sm" variant="danger" phx-click="flash" phx-value-kind="error">
              Trigger error toast
            </.button>
          </div>
        </.section>

        <.section title="Form inputs">
          <.form for={@form} class="max-w-md space-y-1">
            <.input field={@form[:name]} label="Name" placeholder="Truck 01" />
            <.input field={@form[:email]} type="email" label="Email" placeholder="name@fleetms.com" />
            <.input
              field={@form[:role]}
              type="select"
              label="Role"
              prompt="Choose a role"
              options={[Admin: "admin", "Fleet Manager": "manager", Technician: "technician"]}
            />
            <.input
              field={@form[:bio]}
              type="textarea"
              label="Notes"
              placeholder="Write notes here..."
            />
            <.input
              name="error_demo"
              value=""
              label="Field with error"
              errors={["This field is required"]}
            />
            <.input name="agree" type="checkbox" label="I agree to the terms and conditions" />
          </.form>
        </.section>

        <.section title="Date picker & rich text">
          <.form for={@form} class="max-w-2xl space-y-1">
            <.date_input field={@form[:purchase_date]} label="Purchase date" />
            <.rich_text field={@form[:description]} label="Description" />
          </.form>
        </.section>

        <.section title="Tabs">
          <.tabs active={@active_tab} on_select="select-tab">
            <:tab name="overview" label="Overview" icon="fa-list">
              <p class="text-sm text-body">
                Server-driven tabs: the active panel is chosen on the server, so it survives
                LiveView re-renders (uploads, validations) without losing the selected tab.
              </p>
            </:tab>
            <:tab name="specs" label="Specs" icon="fa-gauge">
              <p class="text-sm text-body">The specifications panel.</p>
            </:tab>
            <:tab name="history" label="History" icon="fa-clock-rotate-left">
              <p class="text-sm text-body">The history panel.</p>
            </:tab>
          </.tabs>
        </.section>

        <.section title="Table">
          <.table id="theme-vehicles" rows={@vehicles}>
            <:col :let={v} label="Vehicle">{v.name}</:col>
            <:col :let={v} label="Make">{v.make}</:col>
            <:col :let={v} label="Status">
              <.badge color={v.color}>{v.status}</.badge>
            </:col>
            <:action :let={_v}>
              <.button size="xs" variant="secondary">Edit</.button>
              <.button size="xs" variant="danger">Delete</.button>
            </:action>
          </.table>
        </.section>

        <.section title="Description list">
          <div class="max-w-md">
            <.list>
              <:item title="Name">Truck 01</:item>
              <:item title="Make">Volvo</:item>
              <:item title="Status">
                <.badge color="success">Active</.badge>
              </:item>
            </.list>
          </div>
        </.section>

        <.section title="Breadcrumbs">
          <.breadcrumbs items={[
            %{label: "Dashboard", path: ~p"/", icon: "fa-house"},
            %{label: "Users", path: ~p"/"},
            %{label: "New member"}
          ]} />
        </.section>

        <.section title="Modal">
          <.button data-modal-toggle="theme-modal">Open modal</.button>
          <.modal id="theme-modal" title="Confirm action">
            This is a Flowbite modal styled with the FleetMS theme. It opens and closes via
            Flowbite's data attributes and works across LiveView navigation.
            <:footer>
              <.button variant="danger" data-modal-hide="theme-modal">Confirm</.button>
              <.button variant="secondary" data-modal-hide="theme-modal">Cancel</.button>
            </:footer>
          </.modal>
        </.section>

        <.section title="Live modal (URL-aware)">
          <p class="text-sm text-body">
            Driven by the LiveView rather than Flowbite. Closes on the close button, a backdrop
            click, or the Escape key. In real pages this is opened by navigating to a modal route.
          </p>
          <.button phx-click="open-live-modal">Open live modal</.button>
          <.live_modal
            :if={@show_live_modal}
            id="theme-live-modal"
            show
            on_cancel={JS.push("close-live-modal")}
          >
            <:title>Live modal</:title>
            <p>
              This modal's open state is controlled by the server. It traps focus and can be
              dismissed with Escape or by clicking outside.
            </p>
            <:footer>
              <.button phx-click="close-live-modal">Done</.button>
              <.button variant="secondary" phx-click="close-live-modal">Cancel</.button>
            </:footer>
          </.live_modal>
        </.section>
      </div>
    </Layouts.app>
    """
  end

  attr :title, :string, required: true
  slot :inner_block, required: true

  defp section(assigns) do
    ~H"""
    <section class="space-y-3">
      <h2 class="text-lg font-semibold text-heading border-b border-default pb-2">{@title}</h2>
      {render_slot(@inner_block)}
    </section>
    """
  end
end
