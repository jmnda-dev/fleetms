defmodule FleetmsWeb.CoreComponents do
  @moduledoc """
  Provides core UI components, built on **Flowbite v4** and styled with FleetMS's
  theme tokens.

  ## Styling model

  Components use Flowbite v4's semantic design tokens — e.g. `bg-brand`,
  `text-heading`, `text-body`, `bg-neutral-secondary-medium`, `border-default`,
  `bg-success-soft`, `text-fg-danger-strong`, `rounded-base`. Those tokens are
  defined by the Flowbite theme imported in `assets/css/app.css` and re-pointed
  there to the FleetMS palette (deep-navy brand, slate neutrals, emerald/red/
  amber/sky semantics). They carry **light and dark values**, so components don't
  need per-element `dark:` variants — switching `.dark` on `<html>` re-themes them.

  Icons are **FontAwesome** (`<i class="fa-solid fa-...">`); see `icon/1`.

  References:

    * [Flowbite](https://flowbite.com/docs/getting-started/introduction/)
    * [Tailwind CSS](https://tailwindcss.com)
    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html)
  """
  use Phoenix.Component
  use Gettext, backend: FleetmsWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders a [FontAwesome](https://fontawesome.com/icons) icon.

  Pass the icon name; the solid family is assumed unless you include a family
  prefix (`fa-regular`/`fa-brands`).

  ## Examples

      <.icon name="fa-truck" />
      <.icon name="fa-circle-check" class="text-success" />
      <.icon name="fa-brands fa-github" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: nil
  attr :rest, :global

  def icon(assigns) do
    ~H"""
    <i class={[icon_family(@name), @class]} aria-hidden="true" {@rest}></i>
    """
  end

  defp icon_family("fa-solid " <> _ = name), do: name
  defp icon_family("fa-regular " <> _ = name), do: name
  defp icon_family("fa-brands " <> _ = name), do: name
  defp icon_family("fa-light " <> _ = name), do: name
  defp icon_family(name), do: "fa-solid " <> name

  @doc """
  Renders flash notices as a dismissible toast.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:success} flash={@flash} title="Saved" />
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil

  attr :kind, :atom,
    values: [:info, :success, :warning, :error],
    doc: "used for styling and flash lookup"

  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns =
      assigns
      |> assign_new(:id, fn -> "flash-#{assigns.kind}" end)
      |> assign(:styles, flash_styles(assigns.kind))

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="fixed top-4 right-4 z-50 w-80 sm:w-96 cursor-pointer"
      {@rest}
    >
      <div class={["flex items-start gap-3 p-4 text-sm rounded-base shadow-md", @styles.container]}>
        <.icon name={@styles.icon} class="mt-0.5 shrink-0" />
        <div class="flex-1">
          <p :if={@title} class="font-semibold">{@title}</p>
          <p>{msg}</p>
        </div>
        <button
          type="button"
          class="shrink-0 opacity-60 hover:opacity-100"
          aria-label={gettext("close")}
        >
          <.icon name="fa-xmark" />
        </button>
      </div>
    </div>
    """
  end

  defp flash_styles(:info),
    do: %{container: "text-fg-brand-strong bg-brand-softer", icon: "fa-circle-info"}

  defp flash_styles(:success),
    do: %{container: "text-fg-success-strong bg-success-soft", icon: "fa-circle-check"}

  defp flash_styles(:warning),
    do: %{container: "text-fg-warning bg-warning-soft", icon: "fa-triangle-exclamation"}

  defp flash_styles(:error),
    do: %{container: "text-fg-danger-strong bg-danger-soft", icon: "fa-circle-exclamation"}

  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button>Send!</.button>
      <.button variant="danger" phx-click="delete">Delete</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled form)

  attr :class, :any,
    default: nil,
    doc: "extra classes, appended to the computed variant/size classes"

  attr :variant, :string,
    default: "primary",
    values: ~w(primary secondary success danger warning ghost)

  attr :size, :string, default: "base", values: ~w(xs sm base lg xl)
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    assigns =
      assign(assigns, :class, [
        "inline-flex items-center justify-center box-border border font-medium leading-5",
        "rounded-base shadow-xs focus:outline-none focus:ring-4",
        "disabled:opacity-60 disabled:pointer-events-none",
        button_variant(assigns.variant),
        button_size(assigns.size),
        assigns[:class]
      ])

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  defp button_variant("primary"),
    do:
      "text-white dark:text-primary-900 bg-brand border-transparent hover:bg-brand-strong focus:ring-brand-medium"

  defp button_variant("secondary"),
    do:
      "text-body bg-neutral-secondary-medium border-default-medium hover:bg-neutral-tertiary-medium hover:text-heading focus:ring-neutral-tertiary"

  defp button_variant("success"),
    do:
      "text-white bg-success border-transparent hover:bg-success-strong focus:ring-success-medium"

  defp button_variant("danger"),
    do: "text-white bg-danger border-transparent hover:bg-danger-strong focus:ring-danger-medium"

  defp button_variant("warning"),
    do:
      "text-white bg-warning border-transparent hover:bg-warning-strong focus:ring-warning-medium"

  defp button_variant("ghost"),
    do:
      "text-heading bg-transparent border-transparent hover:bg-neutral-secondary-medium focus:ring-neutral-tertiary"

  defp button_size("xs"), do: "text-xs px-3 py-1.5"
  defp button_size("sm"), do: "text-sm px-3 py-2"
  defp button_size("base"), do: "text-sm px-4 py-2.5"
  defp button_size("lg"), do: "text-base px-5 py-3"
  defp button_size("xl"), do: "text-base px-6 py-3.5"

  @doc """
  Renders a colored badge, useful for statuses.

  ## Examples

      <.badge color="success">Active</.badge>
      <.badge color="warning">Maintenance</.badge>
  """
  attr :color, :string, default: "brand", values: ~w(brand gray success danger warning info)
  attr :size, :string, default: "sm", values: ~w(sm base)
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center font-medium rounded whitespace-nowrap",
      @size == "sm" && "text-xs px-1.5 py-0.5",
      @size == "base" && "text-sm px-2 py-1",
      badge_color(@color),
      @class
    ]}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  defp badge_color("brand"), do: "bg-brand-softer text-fg-brand-strong"
  defp badge_color("gray"), do: "bg-neutral-secondary-medium text-heading"
  defp badge_color("success"), do: "bg-success-soft text-fg-success-strong"
  defp badge_color("danger"), do: "bg-danger-soft text-fg-danger-strong"
  defp badge_color("warning"), do: "bg-warning-soft text-fg-warning"
  # `info` has no Flowbite token; use the sky palette directly.
  defp badge_color("info"), do: "bg-sky-100 text-sky-800 dark:bg-sky-900 dark:text-sky-300"

  @doc """
  Renders a loading spinner (FontAwesome).
  """
  attr :size, :string, default: "base", values: ~w(sm base lg)
  attr :class, :any, default: nil

  def spinner(assigns) do
    ~H"""
    <span role="status">
      <.icon
        name="fa-circle-notch"
        class={[
          "fa-spin text-brand",
          @size == "sm" && "text-base",
          @size == "base" && "text-2xl",
          @size == "lg" && "text-4xl",
          @class
        ]}
      />
      <span class="sr-only">{gettext("Loading...")}</span>
    </span>
    """
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
      <.input field={@form[:role]} type="select" options={["Admin": "admin"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :help, :string, default: nil, doc: "small helper text shown under the input"

  attr :tooltip, :string,
    default: nil,
    doc: "hover tooltip on an info icon beside the label; use sparingly"

  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :any, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :any, default: nil, doc: "the input error class to use over defaults"

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

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="mb-4">
      <label class="flex items-center gap-2">
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class={
            @class ||
              "w-4 h-4 border border-default-medium rounded-xs bg-neutral-secondary-medium text-brand focus:ring-2 focus:ring-brand-soft"
          }
          {@rest}
        />
        <span :if={@label} class="text-sm font-medium text-heading select-none">{@label}</span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
      <.input_help help={@help} />
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="mb-4">
      <.field_label :if={@label} for={@id} label={@label} tooltip={@tooltip} />
      <select
        id={@id}
        name={@name}
        aria-label={@label || @prompt}
        class={[
          @class ||
            "block w-full px-3 py-2.5 bg-neutral-secondary-medium border text-heading text-sm rounded-base shadow-xs focus:ring-brand focus:border-brand",
          @errors == [] && "border-default-medium",
          @errors != [] && (@error_class || "border-danger focus:ring-danger focus:border-danger")
        ]}
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <.error :for={msg <- @errors}>{msg}</.error>
      <.input_help help={@help} />
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="mb-4">
      <.field_label :if={@label} for={@id} label={@label} tooltip={@tooltip} />
      <textarea
        id={@id}
        name={@name}
        class={[
          @class ||
            "block w-full p-3.5 bg-neutral-secondary-medium border text-heading text-sm rounded-base shadow-xs placeholder:text-body focus:ring-brand focus:border-brand",
          @errors == [] && "border-default-medium",
          @errors != [] && (@error_class || "border-danger focus:ring-danger focus:border-danger")
        ]}
        {@rest}
      >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      <.error :for={msg <- @errors}>{msg}</.error>
      <.input_help help={@help} />
    </div>
    """
  end

  # All other inputs: text, datetime-local, url, password, etc.
  def input(assigns) do
    ~H"""
    <div class="mb-4">
      <.field_label :if={@label} for={@id} label={@label} tooltip={@tooltip} />
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          @class ||
            "block w-full px-3 py-2.5 bg-neutral-secondary-medium border text-heading text-sm rounded-base shadow-xs placeholder:text-body focus:ring-brand focus:border-brand",
          @errors == [] && "border-default-medium",
          @errors != [] && (@error_class || "border-danger focus:ring-danger focus:border-danger")
        ]}
        {@rest}
      />
      <.error :for={msg <- @errors}>{msg}</.error>
      <.input_help help={@help} />
    </div>
    """
  end

  # A field label with an optional info-icon tooltip (CSS hover, no JS).
  attr :for, :string, default: nil
  attr :label, :string, required: true
  attr :tooltip, :string, default: nil

  defp field_label(assigns) do
    ~H"""
    <label for={@for} class="mb-2 flex items-center gap-1.5 text-sm font-medium text-heading">
      {@label}
      <span :if={@tooltip} class="group relative inline-flex">
        <.icon name="fa-circle-info" class="cursor-help text-xs text-body" />
        <span class="pointer-events-none absolute bottom-full left-1/2 z-10 mb-1 hidden w-max max-w-xs -translate-x-1/2 rounded bg-gray-900 px-2 py-1 text-xs font-normal text-white group-hover:block dark:bg-gray-700">
          {@tooltip}
        </span>
      </span>
    </label>
    """
  end

  attr :help, :string, default: nil

  defp input_help(assigns) do
    ~H"""
    <p :if={@help} class="mt-1 text-xs text-body">{@help}</p>
    """
  end

  @doc """
  Renders a searchable (and optionally creatable) select built on Tom Select.

  Use this anywhere you'd reach for a `<.input type="select">` but want search,
  multi-select with chips, tag-style creation, or server-side lookups.

  The native `<select>` is wrapped in a `phx-update="ignore"` container so
  LiveView never re-patches the widget's DOM after mount; the `TomSelect` hook
  owns it. Error text is rendered *outside* that container so validation still
  updates normally on every server render.

  ## Modes (hybrid)

    * Static — pass `options`; Tom Select filters them client-side.
    * Remote — pass `remote_event`; typing pushes that event and the LiveView
      replies `{:reply, %{options: [%{value: ..., text: ...}]}, socket}`.

  ## Examples

      <.search_select field={f[:role_ids]} multiple options={@role_options} label="Roles" />

      <.search_select field={f[:vehicle_id]} remote_event="search_vehicles"
        prompt="Search vehicles…" label="Vehicle" />

      <.search_select field={f[:tags]} multiple create
        options={@tag_options} label="Tags" />

  For creatable selects, the typed value is added optimistically on the client;
  the server action is expected to find-or-create on submit (e.g. via
  `manage_relationship(..., on_lookup: :relate, on_no_match: :create)`).

  Dependent inputs: set `dependent_event` on the parent select. On change it
  pushes `{value: ...}`; the LiveView refreshes the dependent select by pushing
  `"tomselect:options:<target_id>"` with `%{options: [...], value: ...}`.
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :field, Phoenix.HTML.FormField, doc: "a form field, e.g. f[:role_ids]"
  attr :errors, :list, default: []

  attr :options, :list,
    default: [],
    doc:
      "for `Phoenix.HTML.Form.options_for_select/2`; in `rich` mode a list of " <>
        "`%{value:, label:, subtitle:}` maps instead"

  attr :prompt, :string, default: nil, doc: "placeholder text shown when empty"
  attr :multiple, :boolean, default: false
  attr :create, :boolean, default: false, doc: "allow creating new entries by typing"

  attr :rich, :boolean,
    default: false,
    doc: "render each option as name + muted subtitle (options are %{value, label, subtitle})"

  attr :remote_event, :string, default: nil, doc: "LiveView event name for server-side search"
  attr :dependent_event, :string, default: nil, doc: "event pushed when this select changes"
  attr :disabled, :boolean, default: false
  attr :rest, :global

  def search_select(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> search_select()
  end

  def search_select(assigns) do
    ~H"""
    <div class="mb-4" data-invalid={@errors != []}>
      <label :if={@label} for={@id} class="block mb-2 text-sm font-medium text-heading">
        {@label}
      </label>
      <%!-- LiveView must not re-patch Tom Select's DOM; the hook owns it. --%>
      <div id={"#{@id}-ts-wrap"} phx-update="ignore">
        <select
          id={@id}
          name={@name}
          multiple={@multiple}
          disabled={@disabled}
          {%{"aria-label" => @label || @prompt}}
          phx-hook="TomSelect"
          data-create={to_string(@create)}
          data-rich={to_string(@rich)}
          data-placeholder={@prompt}
          data-remote-event={@remote_event}
          data-dependent-event={@dependent_event}
          {@rest}
        >
          <option :if={@prompt && !@multiple} value="">{@prompt}</option>
          <%= if @rich do %>
            <option
              :for={opt <- @options}
              value={opt.value}
              selected={rich_selected?(opt.value, @value)}
              data-subtitle={opt.subtitle}
            >
              {opt.label}
            </option>
          <% else %>
            {Phoenix.HTML.Form.options_for_select(@options, @value)}
          <% end %>
        </select>
      </div>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  defp rich_selected?(value, selected) when is_list(selected),
    do: to_string(value) in Enum.map(selected, &to_string/1)

  defp rich_selected?(_value, nil), do: false
  defp rich_selected?(value, selected), do: to_string(value) == to_string(selected)

  @doc """
  Renders a row of coloured tag chips (nothing when the list is empty, unless `empty`
  text is given). Each tag is a `Fleetms.Tagging.Tag` with a `name` and a `color`.

      <.tag_list tags={@issue.tags} />
      <.tag_list tags={@issue.tags} empty="No tags" />
  """
  attr :tags, :list, required: true
  attr :empty, :string, default: nil
  attr :class, :string, default: nil

  def tag_list(assigns) do
    ~H"""
    <div :if={@tags != []} class={["flex flex-wrap gap-1", @class]}>
      <span
        :for={tag <- @tags}
        class={[
          "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
          tag_color_classes(tag.color)
        ]}
      >
        {to_string(tag.name)}
      </span>
    </div>
    <span :if={@tags == [] && @empty} class="text-sm text-body">{@empty}</span>
    """
  end

  # Chip colours per `Fleetms.Tagging.TagColor`. Written as literal class strings so the
  # Tailwind scanner picks them up; light + dark variants for legibility in both themes.
  defp tag_color_classes(:red), do: "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300"

  defp tag_color_classes(:orange),
    do: "bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-300"

  defp tag_color_classes(:amber),
    do: "bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-300"

  defp tag_color_classes(:green),
    do: "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300"

  defp tag_color_classes(:teal),
    do: "bg-teal-100 text-teal-800 dark:bg-teal-900 dark:text-teal-300"

  defp tag_color_classes(:blue),
    do: "bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300"

  defp tag_color_classes(:indigo),
    do: "bg-indigo-100 text-indigo-800 dark:bg-indigo-900 dark:text-indigo-300"

  defp tag_color_classes(:purple),
    do: "bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-300"

  defp tag_color_classes(:pink),
    do: "bg-pink-100 text-pink-800 dark:bg-pink-900 dark:text-pink-300"

  defp tag_color_classes(_slate),
    do: "bg-slate-100 text-slate-800 dark:bg-slate-700 dark:text-slate-200"

  @doc """
  Renders a date input backed by the Flowbite Datepicker.

  Field-aware like `<.input>`. The text input is wrapped in a `phx-update="ignore"`
  container so the `DatePicker` hook owns the widget and LiveView never clobbers
  the calendar or the chosen value; error text renders outside that container so
  validation keeps updating. Picking a date dispatches an `input` event so the
  form's `phx-change`/`phx-submit` see the new value.

  The server receives the value as a `yyyy-mm-dd` string (Ash/Ecto `:date`).

  ## Examples

      <.date_input field={f[:purchase_date]} label="Purchase date" />
      <.date_input field={f[:expires_at]} label="Expiry" min_date="2020-01-01" />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :field, Phoenix.HTML.FormField, doc: "a form field, e.g. f[:purchase_date]"
  attr :errors, :list, default: []
  attr :placeholder, :string, default: "Select date"
  attr :min_date, :string, default: nil
  attr :max_date, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :rest, :global

  def date_input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> date_input()
  end

  def date_input(assigns) do
    ~H"""
    <div class="mb-4" data-invalid={@errors != []}>
      <label :if={@label} for={@id} class="block mb-2 text-sm font-medium text-heading">
        {@label}
      </label>
      <%!-- LiveView must not re-patch the Datepicker's DOM; the hook owns it. --%>
      <div id={"#{@id}-dp-wrap"} phx-update="ignore" class="relative">
        <div class="absolute inset-y-0 left-0 flex items-center pl-3 pointer-events-none">
          <.icon name="fa-calendar-days" class="text-body text-sm" />
        </div>
        <input
          type="text"
          id={@id}
          name={@name}
          value={date_value(@value)}
          phx-hook="DatePicker"
          data-format="yyyy-mm-dd"
          data-min-date={@min_date}
          data-max-date={@max_date}
          disabled={@disabled}
          placeholder={@placeholder}
          autocomplete="off"
          class={[
            "block w-full pl-10 px-3 py-2.5 bg-neutral-secondary-medium border text-heading text-sm rounded-base shadow-xs placeholder:text-body focus:ring-brand focus:border-brand",
            @errors == [] && "border-default-medium",
            @errors != [] && "border-danger focus:ring-danger focus:border-danger"
          ]}
          {@rest}
        />
      </div>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  defp date_value(%Date{} = date), do: Date.to_iso8601(date)
  defp date_value(value) when is_binary(value), do: value
  defp date_value(_), do: nil

  @doc """
  Renders a rich-text (WYSIWYG) editor built on Tiptap, styled with Flowbite.

  Use this in place of `<.input type="textarea">` for formatted body text. The
  control is wrapped in `phx-update="ignore"` so the `RichText` hook owns the
  ProseMirror DOM; the edited HTML is mirrored into a hidden input and an `input`
  event is dispatched so the form observes changes.

  The emitted HTML is **untrusted** — sanitize it server-side with
  `Fleetms.Html.sanitize/1` (typically in an Ash change) before storing, and
  render it with `raw/1` only after sanitizing.

  ## Examples

      <.rich_text field={f[:description]} label="Description" />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :field, Phoenix.HTML.FormField, doc: "a form field, e.g. f[:description]"
  attr :errors, :list, default: []
  attr :rest, :global

  def rich_text(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> rich_text()
  end

  def rich_text(assigns) do
    ~H"""
    <div class="mb-4" data-invalid={@errors != []}>
      <label :if={@label} for={@id} class="block mb-2 text-sm font-medium text-heading">
        {@label}
      </label>
      <%!-- LiveView must not re-patch the editor's DOM; the hook owns it. --%>
      <div
        id={"#{@id}-rt"}
        phx-hook="RichText"
        phx-update="ignore"
        class={[
          "w-full bg-neutral-secondary-medium border rounded-base shadow-xs overflow-hidden",
          @errors == [] && "border-default-medium",
          @errors != [] && "border-danger"
        ]}
        {@rest}
      >
        <div
          data-rt-toolbar
          class="flex flex-wrap items-center gap-0.5 p-2 border-b border-default-medium bg-gray-50 dark:bg-gray-700"
        >
          <.rt_tool action="bold" icon="fa-bold" title="Bold" />
          <.rt_tool action="italic" icon="fa-italic" title="Italic" />
          <.rt_tool action="underline" icon="fa-underline" title="Underline" />
          <.rt_tool action="strike" icon="fa-strikethrough" title="Strikethrough" />
          <span class="mx-1 h-5 w-px bg-default-medium"></span>
          <.rt_tool action="h1" label="H1" title="Heading 1" />
          <.rt_tool action="h2" label="H2" title="Heading 2" />
          <.rt_tool action="h3" label="H3" title="Heading 3" />
          <span class="mx-1 h-5 w-px bg-default-medium"></span>
          <.rt_tool action="bulletList" icon="fa-list-ul" title="Bullet list" />
          <.rt_tool action="orderedList" icon="fa-list-ol" title="Numbered list" />
          <.rt_tool action="blockquote" icon="fa-quote-right" title="Quote" />
          <.rt_tool action="code" icon="fa-code" title="Inline code" />
          <.rt_tool action="link" icon="fa-link" title="Insert link" />
          <.rt_tool action="unlink" icon="fa-link-slash" title="Remove link" />
          <span class="mx-1 h-5 w-px bg-default-medium"></span>
          <.rt_tool action="alignLeft" icon="fa-align-left" title="Align left" />
          <.rt_tool action="alignCenter" icon="fa-align-center" title="Align center" />
          <.rt_tool action="alignRight" icon="fa-align-right" title="Align right" />
          <span class="mx-1 h-5 w-px bg-default-medium"></span>
          <.rt_tool action="undo" icon="fa-rotate-left" title="Undo" />
          <.rt_tool action="redo" icon="fa-rotate-right" title="Redo" />
        </div>
        <div data-rt-content class="text-heading"></div>
        <input type="hidden" id={@id} name={@name} value={@value} data-rt-input />
      </div>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  attr :action, :string, required: true
  attr :icon, :string, default: nil
  attr :label, :string, default: nil
  attr :title, :string, required: true

  defp rt_tool(assigns) do
    ~H"""
    <button
      type="button"
      data-rt-action={@action}
      title={@title}
      aria-label={@title}
      class="inline-flex items-center justify-center w-8 h-8 rounded text-body hover:bg-gray-100 dark:hover:bg-gray-600 hover:text-heading text-sm"
    >
      <.icon :if={@icon} name={@icon} />
      <span :if={@label} class="font-semibold text-xs">{@label}</span>
    </button>
    """
  end

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex items-center gap-1 text-sm text-fg-danger">
      <.icon name="fa-circle-exclamation" class="text-xs" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a tabbed panel whose active tab is driven by the server.

  Unlike client-side (Flowbite) tabs, the active panel is chosen server-side, so
  it survives LiveView re-renders (e.g. after an upload) without losing the
  selected tab. Clicking a tab pushes `on_select` with `phx-value-tab` set to the
  tab's `name`; the parent stores that and passes it back as `active`.

  ## Example

      <.tabs active={@active_tab} on_select="select-tab">
        <:tab name="details" label="Details" icon="fa-list">…</:tab>
        <:tab name="photos" label="Photos" icon="fa-image">…</:tab>
      </.tabs>
  """
  attr :active, :string, required: true
  attr :on_select, :string, required: true

  slot :tab, required: true do
    attr :name, :string, required: true
    attr :label, :string, required: true
    attr :icon, :string
  end

  def tabs(assigns) do
    ~H"""
    <div>
      <div class="border-b border-default">
        <ul class="-mb-px flex flex-wrap text-sm font-medium" role="tablist">
          <li :for={tab <- @tab} role="presentation">
            <button
              type="button"
              role="tab"
              phx-click={@on_select}
              phx-value-tab={tab.name}
              aria-selected={to_string(@active == tab.name)}
              class={[
                "inline-flex items-center gap-2 border-b-2 p-4",
                if(@active == tab.name,
                  do: "border-brand text-brand",
                  else: "border-transparent text-body hover:border-gray-300 hover:text-heading"
                )
              ]}
            >
              <.icon :if={tab[:icon]} name={tab[:icon]} />
              {tab.label}
            </button>
          </li>
        </ul>
      </div>
      <div :for={tab <- @tab} :if={tab.name == @active} class="py-5" role="tabpanel">
        {render_slot(tab)}
      </div>
    </div>
    """
  end

  @doc """
  Renders a collapsible accordion whose open sections are driven by the server.

  Like `tabs/1`, the open/closed state lives in the parent's assigns rather than
  in client-side (Flowbite) JS, so it survives LiveView re-renders — typing in a
  form field no longer collapses the section you're in. Clicking a header pushes
  `on_toggle` with `phx-value-section` set to the section's `name`; the parent
  flips that name in the `open` list it passes back.

  Collapsed panels are hidden with CSS rather than removed, so form fields in
  closed sections stay in the DOM (and keep submitting) and any hooks they carry
  mount once.

  ## Example

      <.accordion open={@open_sections} on_toggle="toggle-section">
        <:section name="general" title="General information">…</:section>
        <:section name="notes" title="Notes">…</:section>
      </.accordion>
  """
  attr :open, :list, required: true, doc: "names of the currently-open sections"
  attr :on_toggle, :string, required: true

  slot :section, required: true do
    attr :name, :string, required: true
    attr :title, :string, required: true
  end

  def accordion(assigns) do
    ~H"""
    <div class="divide-y divide-default overflow-hidden rounded-base border border-default bg-white dark:bg-gray-800">
      <div :for={section <- @section}>
        <h2>
          <button
            type="button"
            phx-click={@on_toggle}
            phx-value-section={section.name}
            aria-expanded={to_string(section.name in @open)}
            class={[
              "flex w-full items-center justify-between gap-3 p-4 text-left font-medium text-heading hover:bg-gray-50 dark:hover:bg-gray-700",
              section.name in @open && "bg-gray-50 dark:bg-gray-700"
            ]}
          >
            <span>{section.title}</span>
            <.icon
              name="fa-chevron-down"
              class={["shrink-0 text-sm transition-transform", section.name in @open && "rotate-180"]}
            />
          </button>
        </h2>
        <div class={["px-4 pb-4", section.name not in @open && "hidden"]}>
          {render_slot(section)}
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a header with title.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[
      @actions != [] &&
        "flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between sm:gap-6",
      "pb-4"
    ]}>
      <div>
        <h1 class="text-xl font-semibold leading-8 text-heading">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="mt-1 text-sm text-body">
          {render_slot(@subtitle)}
        </p>
      </div>
      <%!-- Actions wrap on small screens (they were clipped off the right edge before)
            and sit inline on the right from `sm:` up. --%>
      <div :if={@actions != []} class="flex flex-wrap items-center gap-2 sm:flex-none sm:justify-end">
        {render_slot(@actions)}
      </div>
    </header>
    """
  end

  @doc """
  A friendly empty state for a list/table with nothing to show: an icon, a
  title, an optional message, and an optional call-to-action in the `actions`
  slot. Use inside an empty table cell (`<td colspan=...>`) or a card.

      <.empty_state icon="fa-truck" title="No vehicles yet" message="Add your first one.">
        <.button navigate={~p"/o/ORG/vehicles/new"} size="sm">Add vehicle</.button>
      </.empty_state>
  """
  attr :icon, :string, default: "fa-inbox"
  attr :title, :string, required: true
  attr :message, :string, default: nil
  attr :class, :any, default: nil
  slot :actions

  def empty_state(assigns) do
    ~H"""
    <div class={["flex flex-col items-center justify-center px-4 py-10 text-center", @class]}>
      <span class="mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-gray-100 text-gray-400 dark:bg-gray-700 dark:text-gray-500">
        <.icon name={@icon} class="text-xl" />
      </span>
      <h2 class="text-sm font-semibold text-heading">{@title}</h2>
      <p :if={@message} class="mt-1 max-w-sm text-sm text-body">{@message}</p>
      <div :if={@actions != []} class="mt-4 flex items-center gap-2">{render_slot(@actions)}</div>
    </div>
    """
  end

  @doc """
  A "saved views" control for a list page: remembers the current search/filter/sort
  (the URL query string) under a name, per viewer, in the browser.

  Pass a stable `view_key` unique to the page (e.g. "issues"); the whole control is
  rendered by the `SavedViews` JS hook inside a `phx-update="ignore"` container, so
  LiveView leaves it alone.

  ## Example

      <.saved_views view_key="issues" />
  """
  attr :view_key, :string, required: true
  attr :class, :string, default: nil

  def saved_views(assigns) do
    ~H"""
    <div
      id={"saved-views-#{@view_key}"}
      phx-hook="SavedViews"
      phx-update="ignore"
      data-view-key={@view_key}
      data-save-prompt={gettext("Name this view")}
      data-empty-text={gettext("No saved views yet")}
      class={["relative", @class]}
    >
      <button
        type="button"
        data-sv-toggle
        class="inline-flex items-center justify-center gap-2 rounded-base border border-default-medium bg-white px-4 py-2 text-sm font-medium text-heading hover:bg-gray-50 dark:bg-gray-800 dark:hover:bg-gray-700"
      >
        <.icon name="fa-bookmark" class="text-body text-sm" /> {gettext("Views")}
        <.icon name="fa-chevron-down" class="text-xs" />
      </button>

      <div
        data-sv-menu
        class="absolute right-0 z-20 mt-1 hidden w-60 overflow-hidden rounded-lg border border-default bg-white shadow-lg dark:bg-gray-800"
      >
        <div data-sv-list class="max-h-64 divide-y divide-default overflow-y-auto"></div>
        <button
          type="button"
          data-sv-save
          class="flex w-full items-center gap-2 border-t border-default px-3 py-2 text-sm font-medium text-brand hover:bg-gray-50 dark:hover:bg-gray-700"
        >
          <.icon name="fa-plus" class="text-xs" /> {gettext("Save current view")}
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
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
    <div class="relative overflow-x-auto bg-white dark:bg-gray-800 border border-default rounded-base shadow-sm">
      <table class="w-full text-sm text-left text-body">
        <thead class="text-xs text-heading uppercase bg-gray-50 dark:bg-gray-700 border-b border-default">
          <tr>
            <th :for={col <- @col} scope="col" class="px-4 py-3">{col[:label]}</th>
            <th :if={@action != []} scope="col" class="px-4 py-3">
              <span class="sr-only">{gettext("Actions")}</span>
            </th>
          </tr>
        </thead>
        <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
          <tr
            :for={row <- @rows}
            id={@row_id && @row_id.(row)}
            class="border-b border-default last:border-0 hover:bg-gray-50 dark:hover:bg-gray-700"
          >
            <td
              :for={col <- @col}
              phx-click={@row_click && @row_click.(row)}
              class={["px-4 py-3", @row_click && "cursor-pointer"]}
            >
              {render_slot(col, @row_item.(row))}
            </td>
            <td :if={@action != []} class="px-4 py-3 w-0">
              <div class="flex items-center justify-end gap-3 whitespace-nowrap">
                <%= for action <- @action do %>
                  {render_slot(action, @row_item.(row))}
                <% end %>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a data list (description list).

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <dl class="divide-y divide-default">
      <div
        :for={item <- @item}
        class="grid grid-cols-1 gap-1 py-3 text-sm sm:grid-cols-3 sm:gap-4"
      >
        <dt class="font-medium text-heading">{item.title}</dt>
        <dd class="text-body sm:col-span-2">{render_slot(item)}</dd>
      </div>
    </dl>
    """
  end

  @doc """
  Renders a Flowbite modal.

  Toggle it with a button using Flowbite's data attributes, e.g.
  `<.button data-modal-toggle="my-modal">Open</.button>`, or programmatically.

  ## Examples

      <.modal id="confirm" title="Are you sure?">
        This action cannot be undone.
        <:footer>
          <.button variant="danger" data-modal-hide="confirm">Delete</.button>
          <.button variant="secondary" data-modal-hide="confirm">Cancel</.button>
        </:footer>
      </.modal>
  """
  attr :id, :string, required: true
  attr :title, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true
  slot :footer

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      tabindex="-1"
      aria-hidden="true"
      class="hidden overflow-y-auto overflow-x-hidden fixed top-0 right-0 left-0 z-50 justify-center items-center w-full md:inset-0 h-[calc(100%-1rem)] max-h-full"
      {@rest}
    >
      <div class="relative p-4 w-full max-w-2xl max-h-full">
        <div class="relative bg-white dark:bg-gray-800 border border-default rounded-base shadow-sm p-4 md:p-6">
          <div class="flex items-center justify-between border-b border-default pb-4 md:pb-5">
            <h3 class="text-lg font-medium text-heading">{@title}</h3>
            <button
              type="button"
              class="text-body bg-transparent hover:bg-neutral-tertiary hover:text-heading rounded-base text-sm w-9 h-9 ms-auto inline-flex justify-center items-center"
              data-modal-hide={@id}
            >
              <.icon name="fa-xmark" class="text-lg" />
              <span class="sr-only">{gettext("Close modal")}</span>
            </button>
          </div>

          <div class="space-y-4 md:space-y-6 py-4 md:py-6 text-body">
            {render_slot(@inner_block)}
          </div>

          <div
            :if={@footer != []}
            class="flex items-center border-t border-default gap-4 pt-4 md:pt-5"
          >
            {render_slot(@footer)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a breadcrumb trail.

  Pass `items` as a list of maps with `:label`, an optional `:path` (omit or set
  `nil` for the current page, which renders as plain text), and an optional
  `:icon` (a FontAwesome name).

  ## Examples

      <.breadcrumbs items={[
        %{label: gettext("Dashboard"), path: ~p"/o/\#{org}", icon: "fa-house"},
        %{label: gettext("Users"), path: ~p"/o/\#{org}/users"},
        %{label: gettext("New member")}
      ]} />
  """
  attr :items, :list, required: true
  attr :class, :any, default: nil

  def breadcrumbs(assigns) do
    ~H"""
    <nav class={["flex", @class]} aria-label={gettext("Breadcrumb")}>
      <ol class="inline-flex items-center space-x-1 md:space-x-2 rtl:space-x-reverse">
        <li :for={{item, index} <- Enum.with_index(@items)} class="inline-flex items-center">
          <.icon
            :if={index > 0}
            name="fa-chevron-right"
            class="mx-1 text-xs text-body rtl:rotate-180"
          />
          <.link
            :if={item[:path]}
            navigate={item.path}
            class="inline-flex items-center text-sm font-medium text-body hover:text-heading"
          >
            <.icon :if={item[:icon]} name={item.icon} class="me-2 text-sm" />
            {item.label}
          </.link>
          <span
            :if={is_nil(item[:path])}
            aria-current="page"
            class="inline-flex items-center text-sm font-medium text-heading"
          >
            <.icon :if={item[:icon]} name={item.icon} class="me-2 text-sm" />
            {item.label}
          </span>
        </li>
      </ol>
    </nav>
    """
  end

  @doc """
  Renders a URL-aware modal.

  Unlike `modal/1` (toggled by Flowbite data attributes), this modal is driven by
  the LiveView: render it for the modal `live_action`s with `show` true, and set
  `on_cancel` to patch back to the base route. Closing it (the close button,
  clicking the backdrop, or pressing Escape) runs `on_cancel`.

  ## Example

      # router
      live "/o/:org_id/users", UserLive, :index
      live "/o/:org_id/users/new", UserLive, :new

      # template
      <.live_modal
        :if={@live_action == :new}
        id="user-modal"
        show
        on_cancel={JS.patch(~p"/o/\#{@org}/users")}
      >
        <:title>{gettext("New member")}</:title>
        <.form ...>...</.form>
      </.live_modal>
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  attr :size, :string, default: "lg", values: ~w(sm md lg xl 2xl)
  slot :title
  slot :inner_block, required: true
  slot :footer

  def live_modal(assigns) do
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
        class="fixed inset-0 bg-gray-900/50 transition-opacity"
        aria-hidden="true"
      />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center p-4">
          <.focus_wrap
            id={"#{@id}-container"}
            phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
            phx-key="escape"
            phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
            class={[
              "relative w-full bg-white dark:bg-gray-800 border border-default rounded-base shadow-sm",
              modal_size(@size)
            ]}
          >
            <div class="flex items-center justify-between border-b border-default p-4 md:p-5">
              <h3 :if={@title != []} id={"#{@id}-title"} class="text-lg font-medium text-heading">
                {render_slot(@title)}
              </h3>
              <button
                type="button"
                phx-click={JS.exec("data-cancel", to: "##{@id}")}
                class="text-body bg-transparent hover:bg-neutral-tertiary hover:text-heading rounded-base text-sm w-9 h-9 ms-auto inline-flex justify-center items-center"
              >
                <.icon name="fa-xmark" class="text-lg" />
                <span class="sr-only">{gettext("Close modal")}</span>
              </button>
            </div>

            <div id={"#{@id}-content"} class="space-y-4 p-4 text-body md:p-5">
              {render_slot(@inner_block)}
            </div>

            <div
              :if={@footer != []}
              class="flex items-center gap-3 border-t border-default p-4 md:p-5"
            >
              {render_slot(@footer)}
            </div>
          </.focus_wrap>
        </div>
      </div>
    </div>
    """
  end

  defp modal_size("sm"), do: "max-w-sm"
  defp modal_size("md"), do: "max-w-md"
  defp modal_size("lg"), do: "max-w-lg"
  defp modal_size("xl"), do: "max-w-xl"
  defp modal_size("2xl"), do: "max-w-2xl"

  @doc """
  A sortable table header cell. Clicking emits a `"sort"` event with
  `phx-value-by={field}`; the parent toggles direction and re-patches the URL.

  ## Example

      <.sort_th label={gettext("Name")} field="name" sort_by={@sort_by} sort_order={@sort_order} />
  """
  attr :label, :string, required: true
  attr :field, :string, required: true
  attr :sort_by, :atom, required: true
  attr :sort_order, :atom, required: true
  attr :class, :string, default: nil

  def sort_th(assigns) do
    ~H"""
    <th scope="col" class={["px-4 py-3", @class]}>
      <button
        type="button"
        phx-click="sort"
        phx-value-by={@field}
        class="inline-flex items-center gap-1 font-semibold uppercase hover:text-brand"
      >
        {@label}
        <.icon
          :if={to_string(@sort_by) == @field}
          name={
            if @sort_order == :asc, do: "fa-arrow-up-short-wide", else: "fa-arrow-down-wide-short"
          }
          class="text-xs"
        />
        <.icon
          :if={to_string(@sort_by) != @field}
          name="fa-sort"
          class="text-xs text-gray-300 dark:text-gray-600"
        />
      </button>
    </th>
    """
  end

  @doc """
  The "Showing x–y of n / Page p of t" pagination footer for a list page.

  Emits `"paginate"` with `phx-value-page`. Renders nothing when `count` is 0.

  ## Example

      <.list_pagination count={@count} page={@page} limit={20} />
  """
  attr :count, :integer, required: true
  attr :page, :integer, required: true
  attr :limit, :integer, required: true

  def list_pagination(assigns) do
    total = max(1, ceil(assigns.count / assigns.limit))

    from = (assigns.page - 1) * assigns.limit + 1
    to = min(assigns.page * assigns.limit, assigns.count)
    range = if assigns.count == 0, do: "0", else: "#{from}–#{to}"

    assigns = assign(assigns, total_pages: total, range: range)

    ~H"""
    <div
      :if={@count > 0}
      class="flex flex-col items-center justify-between gap-3 border-t border-default p-4 sm:flex-row"
    >
      <span class="text-sm text-body">
        {gettext("Showing %{range} of %{count}", range: @range, count: @count)}
      </span>
      <div class="flex items-center gap-2">
        <.button
          size="sm"
          variant="secondary"
          disabled={@page <= 1}
          phx-click="paginate"
          phx-value-page={@page - 1}
        >
          <.icon name="fa-chevron-left" class="text-xs" /> {gettext("Previous")}
        </.button>
        <span class="text-sm text-body">
          {gettext("Page %{page} of %{total}", page: @page, total: @total_pages)}
        </span>
        <.button
          size="sm"
          variant="secondary"
          disabled={@page >= @total_pages}
          phx-click="paginate"
          phx-value-page={@page + 1}
        >
          {gettext("Next")} <.icon name="fa-chevron-right" class="text-xs" />
        </.button>
      </div>
    </div>
    """
  end

  @doc """
  The list toolbar: a free-text search box plus a "Filters" trigger button that
  opens the drawer with the matching `drawer_id`. The search form emits `"search"`.

  Pass `filter_count` (number of active filters) to show the badge, and
  `drawer_id` matching the `<.filter_drawer id=...>`.

  ## Example

      <.list_toolbar query={@query} filter_count={map_size(@filters)}
        drawer_id="issue-filters" placeholder={gettext("Search issues…")} />
  """
  attr :query, :string, required: true
  attr :filter_count, :integer, default: 0
  attr :drawer_id, :string, required: true
  attr :placeholder, :string, default: nil

  def list_toolbar(assigns) do
    ~H"""
    <div class="flex flex-col gap-3 border-b border-default p-4 md:flex-row md:items-center md:justify-between">
      <form phx-change="search" phx-submit="search" class="w-full md:max-w-sm">
        <div class="relative">
          <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
            <.icon name="fa-magnifying-glass" class="text-body text-sm" />
          </div>
          <input
            type="search"
            name="q"
            value={@query}
            phx-debounce="300"
            placeholder={@placeholder || gettext("Search…")}
            class="block w-full rounded-base border border-default-medium bg-neutral-secondary-medium p-2 pl-10 text-sm text-heading focus:border-brand focus:ring-brand"
          />
        </div>
      </form>

      <button
        type="button"
        phx-hook="FilterDrawer"
        id={"#{@drawer_id}-trigger"}
        aria-controls={@drawer_id}
        class="inline-flex items-center justify-center gap-2 rounded-base border border-default-medium bg-white px-4 py-2 text-sm font-medium text-heading hover:bg-gray-50 dark:bg-gray-800 dark:hover:bg-gray-700"
      >
        <.icon name="fa-filter" class="text-body text-sm" />
        {gettext("Filters")}
        <span
          :if={@filter_count > 0}
          class="ml-1 rounded-full bg-brand px-2 py-0.5 text-xs font-semibold text-white"
        >
          {@filter_count}
        </span>
      </button>
    </div>
    """
  end

  @doc """
  A left-side filter drawer. The caller supplies the filter fields as the default
  slot; this provides the chrome (header, close button) and the Apply / Clear
  footer. The form emits `"apply-filters"`; the Clear button emits `"clear-filters"`.

  ## Example

      <.filter_drawer id="issue-filters">
        <.search_select ... />
      </.filter_drawer>
  """
  attr :id, :string, required: true
  attr :title, :string, default: nil
  slot :inner_block, required: true

  def filter_drawer(assigns) do
    ~H"""
    <form
      id={@id}
      phx-submit="apply-filters"
      tabindex="-1"
      aria-labelledby={"#{@id}-label"}
      class="fixed left-0 top-0 z-40 h-screen w-full max-w-sm -translate-x-full overflow-y-auto bg-white p-4 transition-transform dark:bg-gray-800"
    >
      <div class="flex items-center justify-between">
        <h5
          id={"#{@id}-label"}
          class="inline-flex items-center text-base font-semibold uppercase text-heading"
        >
          <.icon name="fa-filter" class="me-2" /> {@title || gettext("Filters")}
        </h5>
        <button
          type="button"
          data-drawer-close
          aria-controls={@id}
          class="inline-flex h-8 w-8 items-center justify-center rounded-lg text-body hover:bg-gray-100 hover:text-heading dark:hover:bg-gray-700"
        >
          <.icon name="fa-xmark" />
          <span class="sr-only">{gettext("Close menu")}</span>
        </button>
      </div>

      <div class="mt-5 space-y-5">
        {render_slot(@inner_block)}

        <div class="flex gap-3 pt-2">
          <.button type="submit" class="w-full" data-drawer-close>
            {gettext("Apply filters")}
          </.button>
          <.button
            type="button"
            variant="secondary"
            class="w-full"
            phx-click="clear-filters"
            data-drawer-close
          >
            {gettext("Clear all")}
          </.button>
        </div>
      </div>
    </form>
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      time: 300,
      transition: {"transition-all ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> show("##{id}-container")
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  def hide_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      time: 200,
      transition: {"transition-all ease-in duration-200", "opacity-100", "opacity-0"}
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
end
