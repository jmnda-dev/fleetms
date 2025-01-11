defmodule FleetmsWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At the first glance, this module may seem daunting, but its goal is
  to provide some core building blocks in your application, such as modals,
  tables, and forms. The components are mostly markup and well documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The default components use Tailwind CSS, a utility-first CSS framework.
  See the [Tailwind CSS documentation](https://tailwindcss.com) to learn
  how to customize them or feel free to swap in another framework altogether.

  Icons are provided by [heroicons](https://heroicons.com). See `icon/1` for usage.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  use Gettext, backend: FleetmsWeb.Gettext

  @doc """
  Renders a modal.

  ## Examples

      <.modal id="confirm-modal">
        This is a modal.
      </.modal>

  JS commands may be passed to the `:on_cancel` to configure
  the closing/cancel event, for example:

      <.modal id="confirm" on_cancel={JS.navigate(~p"/posts")}>
        This is another modal.
      </.modal>

  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  attr :max_width, :string, default: "max-w-3xl"
  attr :phx_key, :string, default: "escape"
  attr :phx_click_away, :boolean, default: true
  attr :phx_window_keydown, :boolean, default: true
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div
        id={"#{@id}-bg"}
        class="bg-gray-700/70 dark:bg-gray-900/70 fixed inset-0 transition-opacity"
        aria-hidden="true"
      />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center">
          <div class={["w-full p-4 sm:p-6 lg:py-8", @max_width]}>
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={@phx_window_keydown && JS.exec("data-cancel", to: "##{@id}")}
              phx-key={@phx_key}
              phx-click-away={@phx_click_away && JS.exec("data-cancel", to: "##{@id}")}
              class="shadow-gray-700/10 ring-gray-700/10 relative hidden rounded-2xl bg-white p-14 shadow-lg ring-1 transition dark:bg-gray-800"
            >
              <div class="absolute top-6 right-5">
                <button
                  phx-click={JS.exec("data-cancel", to: "##{@id}")}
                  type="button"
                  class="-m-3 flex-none p-3"
                  aria-label={gettext("close")}
                >
                  <i class="fa-solid fa-xmark h-8 w-8 text-gray-800 dark:text-white" />
                </button>
              </div>
              <div id={"#{@id}-content"}>
                <%= render_slot(@inner_block) %>
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, default: "flash", doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      style="z-index: 200;"
      class={[
        "fixed top-2 right-2 w-80 sm:w-96 rounded-lg p-3 ring-1",
        @kind == :info && "bg-emerald-50 text-emerald-800 ring-emerald-500 fill-cyan-900",
        @kind == :error && "bg-rose-50 text-rose-900 shadow-md ring-rose-500 fill-rose-900"
      ]}
      {@rest}
    >
      <p :if={@title} class="flex items-center gap-1.5 text-sm font-semibold leading-6">
        <.icon :if={@kind == :info} name="hero-information-circle-mini" class="h-4 w-4" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle-mini" class="h-4 w-4" />
        <%= @title %>
      </p>
      <p class="mt-2 text-sm leading-5"><%= msg %></p>
      <button type="button" class="group absolute top-1 right-1 p-2" aria-label={gettext("close")}>
        <.icon name="hero-x-mark-solid" class="h-5 w-5 opacity-40 group-hover:opacity-70" />
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  def flash_group(assigns) do
    ~H"""
    <.flash kind={:info} title="Success!" flash={@flash} />
    <.flash kind={:error} title="Error!" flash={@flash} />
    <.flash
      id="client-error"
      kind={:error}
      title="We can't find the internet"
      phx-disconnected={show(".phx-client-error #client-error")}
      phx-connected={hide("#client-error")}
      hidden
    >
      Attempting to reconnect <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
    </.flash>

    <.flash
      id="server-error"
      kind={:error}
      title="Something went wrong!"
      phx-disconnected={show(".phx-server-error #server-error")}
      phx-connected={hide("#server-error")}
      hidden
    >
      Hang in there while we get back on track
      <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
    </.flash>
    """
  end

  @doc """
  Renders a simple form.

  ## Examples

      <.simple_form for={@form} phx-change="validate" phx-submit="save">
        <.input field={@form[:email]} label="Email"/>
        <.input field={@form[:username]} label="Username" />
        <:actions>
          <.button>Save</.button>
        </:actions>
      </.simple_form>
  """
  attr :for, :any, required: true, doc: "the datastructure for the form"
  attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"

  attr :rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target multipart),
    doc: "the arbitrary HTML attributes to apply to the form tag"

  attr :container_class, :string, default: nil
  slot :inner_block, required: true

  slot :extra_block,
    required: false,
    doc: "the optional extra block that renders extra form fields"

  slot :actions, doc: "the slot for form actions, such as a submit button"

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <%= render_slot(@inner_block, f) %>
      <div :for={action <- @actions} class={@container_class}>
        <%= render_slot(action, f) %>
      </div>
      <div :if={@extra_block != []}>
        <%= render_slot(@extra_block, f) %>
      </div>
    </.form>
    """
  end

  @doc """
  Renders a button.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" class="ml-2">Send!</.button>
  """
  attr :type, :string, default: nil
  attr :size, :atom, values: [:xs, :sm, :md, :lg, :xl], default: :md
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)

  attr :kind, :atom,
    values: [:primary, :info, :light, :success, :warning, :danger],
    default: :primary

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        @size == :xs && "px-3 py-2 text-xs text-center",
        @size == :sm && "px-3 py-2 text-sm text-center",
        @size == :md && "px-5 py-2.5 text-sm",
        @size == :lg && "px-5 py-3 text-base text-center",
        @size == :xl && "px-6 py-3.5 text-base",
        @kind != :light && "text-white",
        "focus:ring-4 font-medium rounded-lg text-sm  mr-2 mb-2 focus:outline-none",
        @kind == :primary &&
          "bg-primary-700 hover:bg-primary-800 focus:ring-primary-300 dark:bg-primary-600 dark:hover:bg-primary-700 dark:focus:ring-primary-800",
        @kind == :info &&
          "bg-blue-700 hover:bg-blue-800 focus:ring-blue-300 dark:bg-blue-600 dark:hover:bg-blue-700 dark:focus:ring-blue-800",
        @kind == :light &&
          "text-gray-900 bg-white border border-gray-300 hover:bg-gray-100 focus:ring-gray-100 me-2 mb-2 dark:bg-gray-800 dark:text-white dark:border-gray-600 dark:hover:bg-gray-700 dark:hover:border-gray-600 dark:focus:ring-gray-700",
        @kind == :success &&
          "bg-green-700 hover:bg-green-800 focus:ring-green-300 dark:bg-green-600 dark:hover:bg-green-700 dark:focus:ring-green-800",
        @kind == :warning &&
          "bg-yellow-700 hover:bg-yellow-800 focus:ring-yellow-300 dark:bg-yellow-600 dark:hover:bg-yellow-700 dark:focus:ring-yellow-800",
        @kind == :danger &&
          "bg-red-700 hover:bg-red-800 focus:ring-red-300 dark:bg-red-600 dark:hover:bg-red-700 dark:focus:ring-red-800",
        "phx-submit-loading:opacity-75",
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as hidden and radio,
  are best written directly in your templates.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :class, :string, default: nil

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file hidden month number password
               range radio search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :checkbox_div_class, :string, default: nil, doc: "whether the checkbox input should be hidden or shown"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class={@checkbox_div_class}>
      <label class="ml-2 text-sm font-medium text-gray-900 dark:text-gray-300">
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class="rounded border-zinc-300 text-zinc-900 focus:ring-0"
          class={[
            "w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 dark:focus:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600",
            @class
          ]}
          {@rest}
        />
        <%= @label %>
      </label>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(%{type: "radio"} = assigns) do
    ~H"""
    <div class="flex items-center mb-4">
      <input
        class="w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600"
        type="radio"
        name={@name}
        value={@value}
        id={@id}
        checked={@checked}
      />
      <label class="ml-2 text-sm font-medium text-gray-900 dark:text-gray-300" for={@id}>
        <%= @label %>
      </label>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div>
      <.label for={@id}><%= @label %></.label>
      <select
        id={@id}
        name={@name}
        class={[
          "bg-gray-50 border text-gray-900 text-sm rounded-lg focus:ring-primary-500 block w-full p-2.5 dark:bg-gray-700 dark:placeholder-gray-400 dark:text-white dark:focus:ring-primary-500",
          @errors == [] && "border-gray-300 focus:border-primary-500 dark:border-gray-600 dark:focus:border-primary-500",
          @errors != [] && "border-rose-400 focus:border-rose-400",
          @class
        ]}
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value=""><%= @prompt %></option>
        <%!-- TODO: Properly handle cases where @options might be nil, for now we default to an empty list like so: <%= Phoenix.HTML.Form.options_for_select(@options || [], @value) %> --%>
        <%= Phoenix.HTML.Form.options_for_select(@options || [], @value) %>
      </select>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div>
      <.label for={@id}><%= @label %></.label>
      <textarea
        id={@id}
        name={@name}
        class={[
          "block p-2.5 w-full text-sm text-gray-900 bg-gray-50 rounded-lg shadow-sm border focus:ring-primary-500 dark:bg-gray-700 dark:placeholder-gray-400 dark:text-white dark:focus:ring-primary-500",
          @errors == [] && "border-gray-300 focus:border-primary-500 dark:border-gray-600 dark:focus:border-primary-500",
          @errors != [] && "border-rose-400 focus:border-rose-400",
          @class
        ]}
        {@rest}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div>
      <.label for={@id}><%= @label %></.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          "bg-gray-50 border text-gray-900 sm:text-sm rounded-lg focus:ring-primary-500 block w-full p-2.5 dark:bg-gray-700 dark:placeholder-gray-400 dark:text-white dark:focus:ring-primary-500",
          @errors == [] && "border-gray-300 focus:border-primary-500 dark:border-gray-600 dark:focus:border-primary-500",
          @errors != [] && "border-rose-400 focus:border-rose-400",
          @class
        ]}
        {@rest}
      />
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="block text-sm font-semibold leading-6 text-gray-800 dark:text-white">
      <%= render_slot(@inner_block) %>
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="mt-3 flex gap-3 text-sm leading-6 text-rose-600 phx-no-feedback:hidden">
      <i class="fa-solid fa-circle-exclamation mt-1.5 h-5 w-5 flex-none"></i>
      <%= render_slot(@inner_block) %>
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  attr :class, :string, default: nil

  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", @class]}>
      <div>
        <h1 class="text-lg font-semibold leading-8 text-gray-800 dark:text-white">
          <%= render_slot(@inner_block) %>
        </h1>
        <p :if={@subtitle != []} class="mt-2 text-sm leading-6 text-gray-600 dark:text-white">
          <%= render_slot(@subtitle) %>
        </p>
      </div>
      <div class="flex-none"><%= render_slot(@actions) %></div>
    </header>
    """
  end

  @doc ~S"""
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id"><%= user.id %></:col>
        <:col :let={user} label="username"><%= user.username %></:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-y-auto px-4 sm:overflow-visible sm:px-0">
      <table class="w-[40rem] mt-11 sm:w-full">
        <thead class="text-sm text-left leading-6 text-zinc-500">
          <tr>
            <th :for={col <- @col} class="p-0 pr-6 pb-4 font-normal"><%= col[:label] %></th>
            <th class="relative p-0 pb-4"><span class="sr-only"><%= gettext("Actions") %></span></th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={match?(%Phoenix.LiveView.LiveStream{}, @rows) && "stream"}
          class="relative divide-y divide-zinc-100 border-t border-zinc-200 text-sm leading-6 text-zinc-700"
        >
          <tr :for={row <- @rows} id={@row_id && @row_id.(row)} class="group hover:bg-zinc-50">
            <td
              :for={{col, i} <- Enum.with_index(@col)}
              phx-click={@row_click && @row_click.(row)}
              class={["relative p-0", @row_click && "hover:cursor-pointer"]}
            >
              <div class="block py-4 pr-6">
                <span class="absolute -inset-y-px right-0 -left-4 group-hover:bg-zinc-50 sm:rounded-l-xl" />
                <span class={["relative", i == 0 && "font-semibold text-zinc-900"]}>
                  <%= render_slot(col, @row_item.(row)) %>
                </span>
              </div>
            </td>
            <td :if={@action != []} class="relative w-14 p-0">
              <div class="relative whitespace-nowrap py-4 text-right text-sm font-medium">
                <span class="absolute -inset-y-px -right-4 left-0 group-hover:bg-zinc-50 sm:rounded-r-xl" />
                <span
                  :for={action <- @action}
                  class="relative ml-4 font-semibold leading-6 text-zinc-900 hover:text-zinc-700"
                >
                  <%= render_slot(action, @row_item.(row)) %>
                </span>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc ~S"""
  Renders a table with generic styling.

  ## Examples

      <.table_2 id="users" rows={@users}>
        <:col :let={user} label="id"><%= user.id %></:col>
        <:col :let={user} label="username"><%= user.username %></:col>
      </.table_2>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
    attr :class, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table_2(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-x-auto">
      <table class="w-full text-sm text-left text-gray-500 dark:text-gray-400">
        <thead class="text-xs text-gray-700 uppercase bg-gray-50 dark:bg-gray-700 dark:text-gray-400">
          <tr>
            <th :for={col <- @col} scope="col" class={["px-4 py-3", col[:class]]}>
              <%= col[:label] %>
            </th>
            <th scope="col" class="px-4 py-3">
              <span class="sr-only"><%= gettext("Actions") %></span>
            </th>
          </tr>
        </thead>
        <tbody id={@id} phx-update={match?(%Phoenix.LiveView.LiveStream{}, @rows) && "stream"}>
          <tr
            :for={row <- @rows}
            id={@row_id && @row_id.(row)}
            class="border-b dark:border-gray-600 hover:bg-gray-100 dark:hover:bg-gray-700"
          >
            <td
              :for={{col, i} <- Enum.with_index(@col)}
              phx-click={@row_click && @row_click.(row)}
              scope={i == 0 && "row"}
              class={[
                i == 0 && "flex items-center",
                @row_click && "hover:cursor-pointer",
                "px-4 py-3 font-medium text-gray-900 whitespace-normal dark:text-white"
              ]}
            >
              <%= render_slot(col, @row_item.(row)) %>
            </td>
            <td :if={@action != []} class="px-4 py-3">
              <%= for action <- @action do %>
                <%= render_slot(action, @row_item.(row)) %>
              <% end %>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  attr :ref, :string, required: true
  attr :upload, :map, required: true
  attr :width, :string, default: "w-full"
  slot :label, required: true
  slot :description, required: false

  def upload_input(assigns) do
    ~H"""
    <div class={["flex items-center justify-center", @width]} phx-drop-target={@ref}>
      <label
        for={@ref}
        class="flex flex-col items-center justify-center w-full h-64 border-2 border-gray-300 border-dashed rounded-lg cursor-pointer bg-gray-50 dark:hover:bg-bray-800 dark:bg-gray-700 hover:bg-gray-100 dark:border-gray-600 dark:hover:border-gray-500 dark:hover:bg-gray-600"
      >
        <div class="flex flex-col items-center justify-center pt-5 pb-6">
          <svg
            class="w-8 h-8 mb-4 text-gray-500 dark:text-gray-400"
            aria-hidden="true"
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 20 16"
          >
            <path
              stroke="currentColor"
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M13 13h3a3 3 0 0 0 0-6h-.025A5.56 5.56 0 0 0 16 6.5 5.5 5.5 0 0 0 5.207 5.021C5.137 5.017 5.071 5 5 5a4 4 0 0 0 0 8h2.167M10 15V6m0 0L8 8m2-2 2 2"
            />
          </svg>
          <p class="mb-2 text-sm text-gray-500 dark:text-gray-400">
            <%= render_slot(@label) %>
          </p>
          <p class="text-xs text-gray-500 dark:text-gray-400">
            <%= render_slot(@description) %>
          </p>
        </div>
        <.live_file_input upload={@upload} class="hidden" />
      </label>
    </div>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title"><%= @post.title %></:item>
        <:item title="Views"><%= @post.views %></:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
    attr :title_class, :string
  end

  def list(assigns) do
    ~H"""
    <div>
      <dl class="-my-4 divide-y divide-gray-200 dark:divide-gray-600">
        <div :for={item <- @item} class="flex gap-4 py-4 text-sm leading-6 sm:gap-8">
          <dt
            class={[
              "w-1/4 font-semibold flex-none text-gray-900 dark:text-white",
              item[:title_class]
            ]}
            id={item[:id]}
            phx-hook={item[:phx_hook]}
          >
            <%= item.title %>
          </dt>
          <dd class="text-gray-600 dark:text-gray-300"><%= render_slot(item) %></dd>
        </div>
      </dl>
    </div>
    """
  end

  @doc """
  Renders a back navigation link.

  ## Examples

      <.back navigate={~p"/posts"}>Back to posts</.back>
  """
  attr :navigate, :any, required: true
  slot :inner_block, required: true

  def back(assigns) do
    ~H"""
    <div class="mt-16">
      <.link
        navigate={@navigate}
        class="text-sm font-semibold leading-6 text-gray-900 hover:text-gray-700 dark:text-white dark:hover:text-gray-300"
      >
        <.icon name="hero-arrow-left-solid" class="h-3 w-3" />
        <%= render_slot(@inner_block) %>
      </.link>
    </div>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from your `assets/vendor/heroicons` directory and bundled
  within your compiled app.css by the plugin in your `assets/tailwind.config.js`.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  @doc """
  Renders a badge component.

  ## Examples

      <.badge kind={:success} label="Back to posts" />
      <.badge kind={:success}>Back to posts<.badge/>
  """
  attr :label, :string, default: nil

  attr :kind, :atom,
    values: [:primary, :secondary, :success, :danger, :warning, :info],
    default: :primary

  attr :class, :string, default: nil
  attr :size, :atom, values: [:md, :lg], default: :md

  attr :rest, :global
  slot :inner_block

  def badge(assigns) do
    ~H"""
    <span
      class={[
        "text-sm font-medium mr-2 rounded",
        @size == :md && "px-2.5 py-0.5",
        @size == :lg && "text-base font-medium px-3 py-1.5",
        @kind == :primary && "bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300",
        @kind == :secondary && "bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-300",
        @kind == :success && "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300",
        @kind == :danger && "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300",
        @kind == :warning && "bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-300",
        @kind == :info && "bg-indigo-100 text-indigo-800 dark:bg-indigo-900 dark:text-indigo-300",
        @class
      ]}
      {@rest}
    >
      <%= @label %>
      <%= render_slot(@inner_block) %>
    </span>
    """
  end

  @doc """
  Renders a breadcrumb component.

  ## Example

      <.breadcrumb class="flex mb-5" links={[
        %{label: "Home", to: ~p"/", link_type: :navigate},
        %{label: "Users", link_type: :navigate, active: true}
      ]} />
  """
  attr :links, :list, required: true
  attr :class, :string, default: "flex mb-5"

  def breadcrumb(assigns) do
    ~H"""
    <nav class={@class} aria-label="Breadcrumb">
      <ol class="inline-flex items-center space-x-1 md:space-x-2">
        <li
          :for={{link_item, index} <- Enum.with_index(@links)}
          class={index == 0 && "inline-flex items-center"}
        >
          <.link
            :if={index == 0}
            navigate={link_item[:link_type] == :navigate && link_item.to}
            patch={link_item[:link_type] == :patch && link_item.to}
            href={link_item[:link_type] == :href && link_item.to}
            class="inline-flex items-center text-sm font-medium text-gray-700 hover:text-primary-600 dark:text-gray-400 dark:hover:text-white"
          >
            <.icon name="hero-home" class="w-6 h-6 text-gray-400" />
            <%= link_item.label %>
          </.link>

          <div :if={index > 0} class="flex items-center">
            <.icon name="hero-chevron-right" class="w-6 h-6 text-gray-400" />
            <.link
              :if={link_item[:active] != true}
              navigate={link_item[:link_type] == :navigate && link_item.to}
              patch={link_item[:link_type] == :patch && link_item.to}
              href={link_item[:link_type] == :href && link_item.to}
              class="ml-1 text-sm font-medium md:ml-2 text-gray-700 hover:text-primary-600 dark:text-gray-400 dark:hover:text-white"
            >
              <%= link_item.label %>
            </.link>
            <span
              :if={link_item[:active]}
              class="ml-1 text-sm font-medium md:ml-2 text-gray-400 dark:text-gray-500"
              aria-current="page"
            >
              <%= link_item.label %>
            </span>
          </div>
        </li>
      </ol>
    </nav>
    """
  end

  @doc """
  A progress bar component.
  """
  attr :progress, :integer, default: 0

  def progress_bar(assigns) do
    ~H"""
    <div class="w-full bg-gray-200 rounded-full h-2.5 dark:bg-gray-700">
      <div class="bg-primary-600 h-2.5 rounded-full" style={"width: #{@progress}%"}></div>
    </div>
    """
  end

  @doc """
  A simple alert component.
  """
  attr :kind, :atom, values: [:info, :success, :warning, :error], default: :info
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def alert(assigns) do
    ~H"""
    <div
      class={[
        "p-4 mb-4 text-sm rounded-lg",
        @kind == :info && "text-blue-800 bg-blue-50 dark:bg-gray-800 dark:text-blue-400",
        @kind == :success && "text-green-800 bg-green-50 dark:bg-gray-800 dark:text-green-400",
        @kind == :warning && "text-yellow-800 bg-yellow-50 dark:bg-gray-800 dark:text-yellow-400",
        @kind == :error && "text-red-800 bg-red-50 dark:bg-gray-800 dark:text-red-400",
        @class
      ]}
      {@rest}
      role="alert"
    >
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  attr :active, :boolean, default: nil
  attr :icon_class, :string, default: nil
  attr :label, :string, required: true
  attr :rest, :global, include: ~w(patch navigate href)

  def tab(assigns) do
    ~H"""
    <.link
      class={[
        "inline-flex items-center justify-center p-4 group rounded-t-lg",
        !@active &&
          "border-b-2 border-transparent  hover:text-gray-600 hover:border-gray-300 dark:hover:text-gray-300",
        @active &&
          "font-semibold text-primary-500 border-b-2 border-primary-500 rounded-t-lg active dark:text-primary-400 dark:border-primary-400"
      ]}
      aria-current={@active && "page"}
      {@rest}
    >
      <i
        :if={not is_nil(@icon_class)}
        class={[
          @icon_class,
          !@active &&
            "text-gray-400 group-hover:text-gray-500 dark:text-gray-500 dark:group-hover:text-gray-300",
          @active && "text-primary-600 dark:text-primary-500"
        ]}
      />

      <%= @label %>
    </.link>
    """
  end

  attr :id, :string, default: "dropdownMenuIconHorizontalButton"
  attr :dropdown_id, :string, default: "dropdownDotsHorizontal"
  slot :dropdown_item, required: true

  def dropdown(assigns) do
    ~H"""
    <button
      id={@id}
      data-dropdown-toggle={@dropdown_id}
      class="inline-flex items-center p-2 text-sm font-medium text-center text-gray-900 bg-white rounded-lg hover:bg-gray-100 focus:ring-4 focus:outline-none dark:text-white focus:ring-gray-50 dark:bg-gray-800 dark:hover:bg-gray-700 dark:focus:ring-gray-600"
      type="button"
    >
      <svg
        class="w-6 h-6"
        aria-hidden="true"
        fill="currentColor"
        viewBox="0 0 20 20"
        xmlns="http://www.w3.org/2000/svg"
      >
        <path d="M6 10a2 2 0 11-4 0 2 2 0 014 0zM12 10a2 2 0 11-4 0 2 2 0 014 0zM16 12a2 2 0 100-4 2 2 0 000 4z">
        </path>
      </svg>
    </button>
    <!-- Dropdown menu -->
    <div id={@dropdown_id} class="hidden z-10 w-44 bg-white rounded divide-y divide-gray-100 shadow">
      <ul class="py-1 text-sm text-gray-700" aria-labelledby={@id}>
        <li :for={item <- @dropdown_item}>
          <%= render_slot(item) %>
        </li>
      </ul>
    </div>
    """
  end

  @doc """
  A spinner component
  """
  attr :rest, :global

  def spinner(assigns) do
    ~H"""
    <div role="status" {@rest}>
      <svg
        aria-hidden="true"
        class="w-8 h-8 mr-2 text-gray-200 animate-spin dark:text-gray-600 fill-blue-600"
        viewBox="0 0 100 101"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
      >
        <path
          d="M100 50.5908C100 78.2051 77.6142 100.591 50 100.591C22.3858 100.591 0 78.2051 0 50.5908C0 22.9766 22.3858 0.59082 50 0.59082C77.6142 0.59082 100 22.9766 100 50.5908ZM9.08144 50.5908C9.08144 73.1895 27.4013 91.5094 50 91.5094C72.5987 91.5094 90.9186 73.1895 90.9186 50.5908C90.9186 27.9921 72.5987 9.67226 50 9.67226C27.4013 9.67226 9.08144 27.9921 9.08144 50.5908Z"
          fill="currentColor"
        />
        <path
          d="M93.9676 39.0409C96.393 38.4038 97.8624 35.9116 97.0079 33.5539C95.2932 28.8227 92.871 24.3692 89.8167 20.348C85.8452 15.1192 80.8826 10.7238 75.2124 7.41289C69.5422 4.10194 63.2754 1.94025 56.7698 1.05124C51.7666 0.367541 46.6976 0.446843 41.7345 1.27873C39.2613 1.69328 37.813 4.19778 38.4501 6.62326C39.0873 9.04874 41.5694 10.4717 44.0505 10.1071C47.8511 9.54855 51.7191 9.52689 55.5402 10.0491C60.8642 10.7766 65.9928 12.5457 70.6331 15.2552C75.2735 17.9648 79.3347 21.5619 82.5849 25.841C84.9175 28.9121 86.7997 32.2913 88.1811 35.8758C89.083 38.2158 91.5421 39.6781 93.9676 39.0409Z"
          fill="currentFill"
        />
      </svg>
      <span class="sr-only">Loading...</span>
    </div>
    """
  end

  @doc """
  A tooltip component
  """
  attr :id, :string, required: true
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def tooltip(assigns) do
    ~H"""
    <div
      id={@id}
      role="tooltip"
      class={[
        "absolute z-10 invisible inline-block px-3 py-2 text-sm font-medium text-white bg-gray-900 rounded-lg shadow-sm opacity-0 tooltip dark:bg-gray-700",
        @class
      ]}
    >
      <%= render_slot(@inner_block) %>
      <div class="tooltip-arrow" data-popper-arrow></div>
    </div>
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> show("##{id}-container")
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(FleetmsWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(FleetmsWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end


  @doc """
  Custom class for the :info LiveToast
  """
  def toast_class_custom_fn(assigns) do
    [
      # base classes
      "group/toast z-100 pointer-events-auto relative w-full items-center justify-between origin-center overflow-hidden rounded-lg p-4 shadow-lg border col-start-1 col-end-1 row-start-1 row-end-2",
      # start hidden if javascript is enabled
      "[@media(scripting:enabled)]:opacity-0 [@media(scripting:enabled){[data-phx-main]_&}]:opacity-100",
      # used to hide the disconnected flashes
      if(assigns[:rest][:hidden] == true, do: "hidden", else: "flex"),
      # override styles per severity
      assigns[:kind] == :info && "!text-blue-800 !bg-blue-50 !dark:bg-gray-800 !dark:text-blue-400",
      assigns[:kind] == :error && "!text-red-700 !bg-red-100 border-red-200"
    ]
  end
end
