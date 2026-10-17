defmodule FleetmsWeb.InspectionLive.New do
  @moduledoc """
  Start and fill an inspection: pick an active form and a vehicle, then answer the
  items of that form's latest published version. Submitting grades the answers
  server-side (see `Fleetms.Inspections.Grade`) and opens the result.

  The fill form is reactive: `phx-change` keeps the current answers in the socket,
  so items whose `visible_when` condition is unmet disappear, and a comment box
  appears for an item whose `comment_on` rule is triggered by the current answer.
  The version filled against is immutable, so what the filler sees is frozen
  regardless of later edits to the living form.
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Images
  alias Fleetms.Inspections
  alias Fleetms.Inspections.{Condition, Grade}
  alias Fleetms.Storage
  alias Fleetms.VehicleManagement

  # Photo items (and items flagged to require a photo) accept image evidence.
  @photo_accept ~w(.jpg .jpeg .png .webp)
  @photo_max 6
  @photo_max_bytes 15_000_000

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: gettext("New inspection"),
       active_link: :inspections,
       form_options: [],
       vehicle_options: [],
       form_id: nil,
       vehicle_id: nil,
       version: nil,
       answers: %{},
       statuses: %{},
       photo_upload_names: [],
       photo_errors: %{}
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scope = socket.assigns.current_scope

    # Preselect a form/vehicle when arriving from a due assignment's "Fill" link,
    # loading that form's latest version so its items render immediately.
    form_id = blank_to_nil(params["form_id"])
    vehicle_id = blank_to_nil(params["vehicle_id"])
    version = if form_id, do: latest_version(scope, form_id), else: nil

    {:noreply,
     socket
     |> assign(
       form_options: form_options(scope),
       vehicle_options: vehicle_options(scope),
       form_id: form_id,
       vehicle_id: vehicle_id,
       version: version
     )
     |> configure_uploads()
     |> recompute()}
  end

  @impl true
  def handle_event("select", params, socket) do
    scope = socket.assigns.current_scope
    form_id = blank_to_nil(params["form_id"])
    vehicle_id = blank_to_nil(params["vehicle_id"])
    form_changed = form_id != socket.assigns.form_id

    version =
      cond do
        is_nil(form_id) -> nil
        form_changed -> latest_version(scope, form_id)
        true -> socket.assigns.version
      end

    answers = if form_changed, do: %{}, else: socket.assigns.answers

    {:noreply,
     socket
     |> assign(
       form_id: form_id,
       vehicle_id: vehicle_id,
       version: version,
       answers: answers,
       photo_errors: %{}
     )
     |> configure_uploads()
     |> recompute()}
  end

  def handle_event("answer", params, socket) do
    # A photo selection also fires this change; keep the current answers when the event
    # carries no answer fields, so attaching a photo never clears what's been filled.
    answers = Map.get(params, "answers", socket.assigns.answers)
    {:noreply, socket |> assign(answers: answers, photo_errors: %{}) |> recompute()}
  end

  def handle_event("cancel-photo", %{"ref" => ref, "upload" => name}, socket) do
    {:noreply, cancel_upload(socket, String.to_existing_atom(name), ref)}
  end

  def handle_event("submit", params, socket) do
    # Stop short of submitting (and of consuming any uploads) if a required photo is
    # missing, so nothing is stored orphaned; keep what's been filled and flag the items.
    case missing_required_photos(socket, params) do
      [] -> submit(socket, params)
      missing -> {:noreply, flag_missing_photos(socket, params, missing)}
    end
  end

  defp submit(socket, params) do
    scope = socket.assigns.current_scope

    answers =
      params["answers"]
      |> Kernel.||(%{})
      |> attach_photos(socket)
      |> attach_signatures(socket)
      |> to_answers()

    case Inspections.submit_inspection(
           %{
             vehicle_id: socket.assigns.vehicle_id,
             inspection_form_version_id: socket.assigns.version.id,
             answers: answers
           },
           scope: scope
         ) do
      {:ok, inspection} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Inspection submitted."))
         |> push_navigate(to: ~p"/o/#{org(socket)}/inspections/#{inspection.id}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not submit the inspection."))}
    end
  end

  defp flag_missing_photos(socket, params, missing) do
    errors = Map.new(missing, fn {item, count} -> {item.id, photo_error_message(count)} end)
    labels = Enum.map_join(missing, ", ", fn {item, _count} -> item.label end)

    socket
    |> assign(answers: Map.get(params, "answers", socket.assigns.answers), photo_errors: errors)
    |> recompute()
    |> put_flash(
      :error,
      gettext("Add the required photo(s) before submitting: %{items}", items: labels)
    )
  end

  # Recompute naive per-item statuses (for comment prompts) and the condition
  # context (for visibility) from the current answers.
  defp recompute(%{assigns: %{version: nil}} = socket), do: assign(socket, statuses: %{})

  defp recompute(%{assigns: %{version: version, answers: answers}} = socket) do
    statuses = Grade.statuses(version.schema, to_answers(answers))
    assign(socket, statuses: statuses)
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
        %{label: gettext("Inspections"), path: ~p"/o/#{org(assigns)}/inspections"},
        %{label: @page_title}
      ]} />

      <.header>{gettext("New inspection")}</.header>

      <form id="inspection-picker" phx-change="select" class="mt-6 grid gap-4 sm:grid-cols-2">
        <div>
          <label for="inspection-form-select" class="mb-1 block text-sm font-medium text-heading">
            {gettext("Form")}
          </label>
          <select id="inspection-form-select" name="form_id" class={input_class()}>
            <option value="">{gettext("Select a form…")}</option>
            <option :for={{label, id} <- @form_options} value={id} selected={id == @form_id}>
              {label}
            </option>
          </select>
        </div>
        <div>
          <label for="inspection-vehicle-select" class="mb-1 block text-sm font-medium text-heading">
            {gettext("Vehicle")}
          </label>
          <select id="inspection-vehicle-select" name="vehicle_id" class={input_class()}>
            <option value="">{gettext("Select a vehicle…")}</option>
            <option :for={{label, id} <- @vehicle_options} value={id} selected={id == @vehicle_id}>
              {label}
            </option>
          </select>
        </div>
      </form>

      <div
        :if={@form_id && is_nil(@version)}
        class="mt-6 rounded-base border border-amber-300 bg-amber-50 p-4 text-sm text-amber-800 dark:border-amber-800 dark:bg-amber-900/30 dark:text-amber-300"
      >
        {gettext("This form has no published version yet. Publish it in the builder first.")}
      </div>

      <form
        :if={@version && @vehicle_id}
        id="inspection-fill-form"
        phx-change="answer"
        phx-submit="submit"
        class="mt-6 space-y-6"
      >
        <div
          :for={section <- visible_sections(@version.schema.sections, @answers, @statuses)}
          class="rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800"
        >
          <h3 :if={section.title} class="mb-1 text-lg font-semibold text-heading">{section.title}</h3>
          <p :if={section.description} class="mb-4 text-sm text-body">{section.description}</p>
          <div class="space-y-5">
            <.fill_item
              :for={item <- visible(section.items, @answers, @statuses)}
              item={item}
              answer={Map.get(@answers, item.id, %{})}
              show_comment={show_comment?(item, @statuses)}
              show_photo={show_photo?(item, @statuses)}
              upload={item_upload(assigns, item)}
              photo_error={Map.get(@photo_errors, item.id)}
            />
          </div>
        </div>

        <div class="flex items-center gap-3">
          <.button type="submit" phx-disable-with={gettext("Submitting…")}>
            {gettext("Submit inspection")}
          </.button>
          <.button variant="secondary" navigate={~p"/o/#{org(assigns)}/inspections"}>
            {gettext("Cancel")}
          </.button>
        </div>
      </form>
    </Layouts.app>
    """
  end

  # --- item rendering ---

  attr :item, :map, required: true
  attr :answer, :map, required: true
  attr :show_comment, :boolean, default: false
  attr :show_photo, :boolean, default: false
  attr :upload, :any, default: nil
  attr :photo_error, :string, default: nil

  defp fill_item(assigns) do
    assigns = assign(assigns, type: assigns.item.config.type, config: assigns.item.config.value)

    ~H"""
    <div>
      <%= if @type != :instruction do %>
        <label class="block text-sm font-medium text-heading">
          {@item.label}<span :if={@item.required} class="text-red-500">*</span>
        </label>
        <p :if={@item.help_text} class="mb-1 text-xs text-body">{@item.help_text}</p>
      <% end %>

      <%= case @type do %>
        <% :instruction -> %>
          <div class="rounded-base bg-gray-50 p-3 text-sm text-body dark:bg-gray-700">
            {@config.body}
          </div>
        <% :pass_fail -> %>
          <div class="flex flex-wrap gap-2">
            <.choice
              name={name(@item, "value")}
              value="pass"
              label={@config.pass_label}
              checked={@answer["value"] == "pass"}
              tone={:pass}
            />
            <.choice
              name={name(@item, "value")}
              value="fail"
              label={@config.fail_label}
              checked={@answer["value"] == "fail"}
              tone={:fail}
            />
            <.choice
              :if={@config.allow_na}
              name={name(@item, "value")}
              value="na"
              label="N/A"
              checked={@answer["value"] == "na"}
            />
          </div>
        <% t when t in [:number, :meter] -> %>
          <div class="flex items-center gap-2">
            <input
              type="number"
              step="any"
              phx-debounce="300"
              name={name(@item, "value")}
              value={@answer["value"]}
              class={input_class()}
            />
            <span :if={@config.unit && @config.unit != ""} class="text-sm text-body">
              {@config.unit}
            </span>
          </div>
        <% :single_select -> %>
          <div :if={@config.display == :radio} class="flex flex-wrap gap-2">
            <.choice
              :for={opt <- @config.options}
              name={name(@item, "value")}
              value={opt.value}
              label={opt.label}
              checked={@answer["value"] == opt.value}
              tone={if opt.fail?, do: :fail, else: :brand}
            />
          </div>
          <select
            :if={@config.display != :radio}
            name={name(@item, "value")}
            class={input_class()}
          >
            <option value="">{gettext("Select…")}</option>
            <option
              :for={opt <- @config.options}
              value={opt.value}
              selected={@answer["value"] == opt.value}
            >
              {opt.label}
            </option>
          </select>
        <% :multi_select -> %>
          <div class="space-y-1">
            <label :for={opt <- @config.options} class="flex items-center gap-2 text-sm text-body">
              <input
                type="checkbox"
                name={name(@item, "values") <> "[]"}
                value={opt.value}
                checked={opt.value in (@answer["values"] || [])}
              /> {opt.label}
            </label>
          </div>
        <% :date -> %>
          <input
            type={if @config.mode == :datetime, do: "datetime-local", else: "date"}
            name={name(@item, "value")}
            value={@answer["value"]}
            class={input_class()}
          />
        <% :text -> %>
          <textarea
            :if={@config.multiline}
            phx-debounce="300"
            name={name(@item, "value")}
            rows="3"
            class={input_class()}
          >{@answer["value"]}</textarea>
          <input
            :if={!@config.multiline}
            type="text"
            phx-debounce="300"
            name={name(@item, "value")}
            value={@answer["value"]}
            class={input_class()}
          />
        <% :photo -> %>
          <%!-- The upload block below renders the capture UI for photo-capable items. --%>
        <% :signature -> %>
          <div id={"sig-#{@item.id}"} phx-hook="SignaturePad" class="max-w-md">
            <div id={"sig-pad-#{@item.id}"} phx-update="ignore">
              <canvas
                data-sig-canvas
                width="600"
                height="180"
                class="h-44 w-full touch-none rounded-base border border-default-medium bg-white"
              >
              </canvas>
            </div>
            <input
              type="hidden"
              name={name(@item, "signature_data")}
              value={@answer["signature_data"]}
              data-sig-input
            />
            <button
              type="button"
              data-sig-clear
              class="mt-1 text-xs text-body hover:text-heading hover:underline"
            >
              {gettext("Clear")}
            </button>
          </div>
      <% end %>

      <div :if={@upload && @show_photo} class="mt-2 space-y-2">
        <div :if={@upload.entries != []} class="flex flex-wrap gap-2">
          <div :for={entry <- @upload.entries} class="w-16">
            <div class="relative">
              <.live_img_preview entry={entry} class="h-16 w-16 rounded-base object-cover" />
              <button
                type="button"
                phx-click="cancel-photo"
                phx-value-ref={entry.ref}
                phx-value-upload={@upload.name}
                class="absolute -right-1.5 -top-1.5 flex h-5 w-5 items-center justify-center rounded-full bg-gray-900/70 text-xs text-white"
                aria-label={gettext("Remove")}
              >
                <.icon name="fa-xmark" class="text-[10px]" />
              </button>
              <div
                :if={entry.progress > 0 and entry.progress < 100}
                class="absolute inset-x-0 bottom-0 h-1 bg-black/40"
              >
                <div class="h-full bg-brand transition-all" style={"width: #{entry.progress}%"}></div>
              </div>
            </div>
            <p :for={err <- upload_errors(@upload, entry)} class="mt-0.5 text-[10px] text-fg-danger">
              {upload_error(err)}
            </p>
          </div>
        </div>
        <label class="inline-flex cursor-pointer items-center gap-2 rounded-base border border-default-medium px-3 py-2 text-sm text-heading hover:bg-gray-50 dark:hover:bg-gray-700">
          <.icon name="fa-camera" /> {gettext("Add photo")}
          <.live_file_input upload={@upload} aria-label={gettext("Upload file")} class="sr-only" />
        </label>
        <p :for={err <- upload_errors(@upload)} class="text-xs text-fg-danger">{upload_error(err)}</p>
        <p :if={@photo_error} class="text-xs text-fg-danger">{@photo_error}</p>
      </div>

      <div :if={@show_comment} class="mt-2">
        <textarea
          phx-debounce="300"
          name={name(@item, "comment")}
          rows="2"
          placeholder={gettext("Add a comment…")}
          class={input_class()}
        >{@answer["comment"]}</textarea>
      </div>
    </div>
    """
  end

  attr :name, :string, required: true
  attr :value, :string, required: true
  attr :label, :string, required: true
  attr :checked, :boolean, default: false
  attr :tone, :atom, default: :brand, values: [:brand, :pass, :fail]

  defp choice(assigns) do
    ~H"""
    <label class={[
      "flex cursor-pointer items-center gap-2 rounded-base border px-3 py-2 text-sm font-medium",
      !@checked && "border-default text-heading hover:bg-gray-50 dark:hover:bg-gray-700",
      @checked && @tone == :pass &&
        "border-green-500 bg-green-50 text-green-800 dark:border-green-500 dark:bg-green-900/30 dark:text-green-300",
      @checked && @tone == :fail &&
        "border-red-500 bg-red-50 text-red-800 dark:border-red-500 dark:bg-red-900/30 dark:text-red-300",
      @checked && @tone == :brand && "border-brand bg-brand-softer text-fg-brand"
    ]}>
      <input type="radio" name={@name} value={@value} checked={@checked} class="sr-only" />
      <.icon :if={@checked} name="fa-check" class="text-xs" />
      {@label}
    </label>
    """
  end

  defp name(item, field), do: "answers[#{item.id}][#{field}]"

  defp input_class,
    do:
      "w-full rounded-base border border-default-medium bg-neutral-secondary-medium p-2 text-sm text-heading"

  # --- visibility & comments ---

  defp visible(items, answers, statuses) do
    Enum.filter(items, &Condition.visible?(&1.visible_when, condition_context(answers, statuses)))
  end

  # Sections with an unmet `visible_when` are hidden entirely (their items are also
  # graded as skipped on submit — see Fleetms.Inspections.Grade).
  defp visible_sections(sections, answers, statuses) do
    Enum.filter(
      sections,
      &Condition.visible?(&1.visible_when, condition_context(answers, statuses))
    )
  end

  defp condition_context(answers, statuses) do
    %{
      answers: Map.new(answers, fn {id, attrs} -> {id, attrs["value"]} end),
      statuses: statuses
    }
  end

  defp show_comment?(item, statuses) do
    triggered?(Map.get(item.config.value, :comment_on), item, statuses)
  end

  # A photo item always offers capture (it IS the input); other items offer it only when
  # their `photo_on` rule fires for the current status (e.g. `:fail`).
  defp show_photo?(%{config: %{type: :photo}}, _statuses), do: true

  defp show_photo?(item, statuses) do
    triggered?(Map.get(item.config.value, :photo_on), item, statuses)
  end

  defp triggered?(:always, _item, _statuses), do: true
  defp triggered?(:pass, item, statuses), do: Map.get(statuses, item.id) == :pass
  defp triggered?(:fail, item, statuses), do: Map.get(statuses, item.id) == :fail
  defp triggered?(_rule, _item, _statuses), do: false

  # --- data ---

  defp to_answers(answers_map) do
    Enum.map(answers_map, fn {item_id, attrs} -> Map.put(attrs, "item_id", item_id) end)
  end

  # --- photo uploads ---

  # Register one upload per photo-capable item on the current version, dropping any from
  # a previously selected form. Photo-capable = a photo item, or one flagged to require a
  # photo (its config's `photo_on` is not `:never`).
  defp configure_uploads(socket) do
    socket = Enum.reduce(socket.assigns.photo_upload_names, socket, &disallow_upload(&2, &1))
    items = if socket.assigns.version, do: photo_items(socket.assigns.version), else: []

    {socket, names} =
      Enum.reduce(items, {socket, []}, fn item, {s, acc} ->
        name = upload_name(item)

        s =
          allow_upload(s, name,
            accept: @photo_accept,
            max_entries: @photo_max,
            max_file_size: @photo_max_bytes,
            # Upload as soon as a photo is attached, so its progress bar fills while the
            # inspector keeps working; the files are held and consumed on submit.
            auto_upload: true
          )

        {s, [name | acc]}
      end)

    assign(socket, photo_upload_names: names)
  end

  defp photo_items(version) do
    for section <- version.schema.sections, item <- section.items, photo_capable?(item), do: item
  end

  defp photo_capable?(item) do
    item.config.type == :photo or
      Map.get(item.config.value, :photo_on, :never) not in [nil, :never]
  end

  defp upload_name(item), do: String.to_atom("photo_#{item.id}")

  # `@uploads` only exists once at least one upload has been allowed (a form with photo
  # items); otherwise there's nothing to look up.
  defp item_upload(%{uploads: uploads}, item), do: Map.get(uploads, upload_name(item))
  defp item_upload(_assigns, _item), do: nil

  # --- required-photo enforcement ---

  # Visible items that need a photo but don't have enough attached yet, as
  # `{item, required_count}`. A photo item needs its `min_photos`; any other item whose
  # `photo_on` rule fires for its current status needs at least one.
  defp missing_required_photos(%{assigns: %{version: nil}}, _params), do: []

  defp missing_required_photos(socket, params) do
    version = socket.assigns.version
    answers_map = Map.get(params, "answers", %{})
    statuses = Grade.statuses(version.schema, to_answers(answers_map))

    for section <- version.schema.sections,
        item <- visible(section.items, answers_map, statuses),
        required = required_photo_count(item, statuses),
        required > 0,
        photo_count(socket, item) < required do
      {item, required}
    end
  end

  defp required_photo_count(%{config: %{type: :photo}} = item, _statuses),
    do: Map.get(item.config.value, :min_photos, 0)

  defp required_photo_count(item, statuses) do
    if triggered?(Map.get(item.config.value, :photo_on), item, statuses), do: 1, else: 0
  end

  defp photo_count(socket, item) do
    case item_upload(socket.assigns, item) do
      %{entries: entries} -> length(entries)
      _ -> 0
    end
  end

  defp photo_error_message(1), do: gettext("A photo is required.")

  defp photo_error_message(count),
    do: gettext("At least %{count} photos are required.", count: count)

  # Consume each photo item's uploads into stored images and merge their keys onto that
  # item's answer.
  defp attach_photos(answers_map, socket) do
    items = if socket.assigns.version, do: photo_items(socket.assigns.version), else: []

    Enum.reduce(items, answers_map, fn item, acc ->
      photos =
        socket
        |> consume_uploaded_entries(upload_name(item), fn %{path: path}, _entry ->
          {:ok, store_photo(path)}
        end)
        |> Enum.reject(&is_nil/1)

      if photos == [], do: acc, else: put_photos(acc, item.id, photos)
    end)
  end

  defp put_photos(answers_map, item_id, photos) do
    Map.update(answers_map, item_id, %{"photos" => photos}, &Map.put(&1, "photos", photos))
  end

  # Turn a temp upload into a stored display image + thumbnail; nil on any failure.
  defp store_photo(source) do
    base = "inspections/answers/#{Ecto.UUID.generate()}"
    image_key = base <> ".jpg"
    thumbnail_key = base <> "_thumb.jpg"
    display_tmp = tmp_path()
    thumb_tmp = tmp_path()

    try do
      with {:ok, _} <- Images.display(source, display_tmp),
           {:ok, _} <- Images.thumbnail(source, thumb_tmp),
           {:ok, _} <- Storage.put(image_key, display_tmp),
           {:ok, _} <- Storage.put(thumbnail_key, thumb_tmp) do
        %{"image_key" => image_key, "thumbnail_key" => thumbnail_key}
      else
        _ -> nil
      end
    after
      File.rm(display_tmp)
      File.rm(thumb_tmp)
    end
  end

  defp tmp_path, do: Path.join(System.tmp_dir!(), "fleetms-upload-#{Ecto.UUID.generate()}.jpg")

  # --- signature capture ---

  # Signature items carry their drawing as a PNG data URL in a hidden `signature_data`
  # field (written by the SignaturePad hook). Decode it, store it like a photo, and set
  # the item's `signature` answer; the raw data URL is dropped from the answer.
  defp attach_signatures(answers_map, socket) do
    items = if socket.assigns.version, do: signature_items(socket.assigns.version), else: []

    Enum.reduce(items, answers_map, fn item, acc ->
      case acc[item.id] do
        %{"signature_data" => data} = attrs when is_binary(data) and data != "" ->
          attrs = Map.delete(attrs, "signature_data")

          attrs =
            case store_signature(data) do
              nil -> attrs
              stored -> Map.put(attrs, "signature", stored)
            end

          Map.put(acc, item.id, attrs)

        _ ->
          acc
      end
    end)
  end

  defp signature_items(version) do
    for section <- version.schema.sections,
        item <- section.items,
        item.config.type == :signature,
        do: item
  end

  defp store_signature("data:image/png;base64," <> b64) do
    case Base.decode64(b64) do
      {:ok, binary} ->
        tmp = tmp_path()

        try do
          case File.write(tmp, binary) do
            :ok -> store_photo(tmp)
            _ -> nil
          end
        after
          File.rm(tmp)
        end

      :error ->
        nil
    end
  end

  defp store_signature(_), do: nil

  defp upload_error(:too_large), do: gettext("That file is too large.")
  defp upload_error(:too_many_files), do: gettext("Too many photos on one item.")
  defp upload_error(:not_accepted), do: gettext("Only image files are allowed.")
  defp upload_error(_), do: gettext("That file could not be added.")

  defp form_options(scope) do
    case Inspections.list_inspection_forms(%{}, scope: scope, page: [limit: 200]) do
      {:ok, page} ->
        page.results
        |> Enum.filter(&(&1.status == :active))
        |> Enum.map(&{&1.title, &1.id})

      _ ->
        []
    end
  end

  defp vehicle_options(scope) do
    case VehicleManagement.list_selectable_vehicles(scope: scope) do
      {:ok, vehicles} -> Enum.map(vehicles, &{&1.name, &1.id})
      _ -> []
    end
  end

  defp latest_version(scope, form_id) do
    case Inspections.get_inspection_form(form_id, scope: scope) do
      {:ok, %{versions: [latest | _]}} ->
        Inspections.get_inspection_form_version!(latest.id, scope: scope)

      _ ->
        nil
    end
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
