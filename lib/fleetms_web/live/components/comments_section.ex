defmodule FleetmsWeb.CommentsSection do
  @moduledoc """
  A reusable comment thread for a record — issues, work orders, vehicles and
  inspections. Renders the existing comments and a compose box with a server-driven
  `@mention` autocomplete, and handles posting, editing and deleting inline.

  Parent LiveViews render it with the record it belongs to:

      <.live_component
        module={FleetmsWeb.CommentsSection}
        id={"comments-\#{@issue.id}"}
        scope={@current_scope}
        parent_key={:issue_id}
        parent_id={@issue.id}
      />

  Mentions are recorded explicitly: picking a member from the dropdown inserts
  `@Name` at the end of the draft and remembers their id, so there's no fuzzy text
  parsing. Only mentions still present in the body when posting are kept.
  """
  use FleetmsWeb, :live_component

  alias Fleetms.Accounts
  alias Fleetms.Comments
  alias Fleetms.Scope

  # The member currently being typed: an `@token` at the very end of the draft.
  @mention_at_end ~r/@([\p{L}\p{N}._-]*)$/u
  @max_suggestions 6

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:draft, fn -> "" end)
      |> assign_new(:mentioned, fn -> %{} end)
      |> assign_new(:suggestions, fn -> [] end)
      |> assign_new(:editing_id, fn -> nil end)
      |> assign_new(:error, fn -> nil end)
      |> assign_new(:members, fn -> members(assigns.scope) end)
      |> assign_new(:can_create, fn -> Scope.has_permission?(assigns.scope, :create_comment) end)
      |> assign_new(:can_moderate, fn ->
        Scope.has_permission?(assigns.scope, :delete_comments)
      end)

    {:ok, assign(socket, comments: load_comments(socket.assigns))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <ul class="space-y-4">
        <li
          :for={comment <- @comments}
          id={"comment-#{comment.id}"}
          class="flex gap-3"
        >
          <div class={[
            "flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-xs font-semibold text-white",
            avatar_color(comment.author_id)
          ]}>
            {initials(author_name(comment.author))}
          </div>

          <div class="min-w-0 flex-1">
            <div class="flex items-center gap-2">
              <span class="text-sm font-semibold text-heading">
                {author_name(comment.author)}
              </span>
              <span class="text-xs text-body">{time_ago(comment.inserted_at)}</span>
            </div>

            <%= if @editing_id == comment.id do %>
              <form phx-submit="save-edit" phx-target={@myself} class="mt-1">
                <input type="hidden" name="comment_id" value={comment.id} />
                <textarea
                  name="body"
                  rows="2"
                  class="block w-full rounded-base border border-default-medium bg-neutral-secondary-medium p-2 text-sm text-heading focus:border-brand focus:ring-brand"
                >{comment.body}</textarea>
                <div class="mt-1 flex gap-2">
                  <.button size="xs" type="submit">{gettext("Save")}</.button>
                  <.button
                    size="xs"
                    type="button"
                    variant="secondary"
                    phx-click="cancel-edit"
                    phx-target={@myself}
                  >
                    {gettext("Cancel")}
                  </.button>
                </div>
              </form>
            <% else %>
              <p class="mt-0.5 whitespace-pre-wrap break-words text-sm text-body">
                {rendered_body(comment.body, mentioned_names(comment, @members))}
              </p>

              <div class="mt-1 flex gap-3">
                <button
                  :if={own?(comment, @scope)}
                  type="button"
                  phx-click="edit-comment"
                  phx-value-id={comment.id}
                  phx-target={@myself}
                  class="text-xs text-body hover:text-heading"
                >
                  {gettext("Edit")}
                </button>
                <button
                  :if={own?(comment, @scope) or @can_moderate}
                  type="button"
                  phx-click="delete-comment"
                  phx-value-id={comment.id}
                  phx-target={@myself}
                  data-confirm={gettext("Delete this comment?")}
                  class="text-xs text-fg-danger hover:underline"
                >
                  {gettext("Delete")}
                </button>
              </div>
            <% end %>
          </div>
        </li>

        <li :if={@comments == []} class="py-6 text-center text-sm text-body">
          {gettext("No comments yet. Start the conversation.")}
        </li>
      </ul>

      <div :if={@can_create} class="relative mt-6 border-t border-default pt-4">
        <form
          id={"#{@id}-compose"}
          phx-submit="post-comment"
          phx-change="draft-changed"
          phx-target={@myself}
        >
          <textarea
            name="body"
            rows="3"
            phx-debounce="150"
            placeholder={gettext("Write a comment… use @ to mention someone")}
            class="block w-full rounded-base border border-default-medium bg-neutral-secondary-medium p-2 text-sm text-heading focus:border-brand focus:ring-brand"
          >{@draft}</textarea>

          <ul
            :if={@suggestions != []}
            class="absolute z-10 mt-1 max-h-56 w-72 overflow-y-auto rounded-base border border-default bg-white shadow-lg dark:bg-gray-800"
          >
            <li :for={member <- @suggestions}>
              <button
                type="button"
                phx-click="pick-mention"
                phx-value-id={member.id}
                phx-value-name={member.name}
                phx-target={@myself}
                class="flex w-full items-center gap-2 px-3 py-2 text-left text-sm text-heading hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                <span class={[
                  "flex h-6 w-6 items-center justify-center rounded-full text-[10px] font-semibold text-white",
                  avatar_color(member.id)
                ]}>
                  {initials(member.name)}
                </span>
                {member.name}
              </button>
            </li>
          </ul>

          <p :if={@error} class="mt-1 text-xs text-fg-danger">{@error}</p>

          <div class="mt-2 flex justify-end">
            <.button size="sm" type="submit">
              <.icon name="fa-paper-plane" class="me-2" /> {gettext("Post comment")}
            </.button>
          </div>
        </form>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("draft-changed", %{"body" => body}, socket) do
    suggestions =
      case active_query(body) do
        nil -> []
        query -> suggest(socket.assigns.members, query)
      end

    {:noreply, assign(socket, draft: body, suggestions: suggestions, error: nil)}
  end

  def handle_event("pick-mention", %{"id" => id, "name" => name}, socket) do
    draft = insert_mention(socket.assigns.draft, name)
    mentioned = Map.put(socket.assigns.mentioned, id, name)
    {:noreply, assign(socket, draft: draft, mentioned: mentioned, suggestions: [])}
  end

  def handle_event("post-comment", %{"body" => body}, socket) do
    body = String.trim(body)

    if body == "" do
      {:noreply, assign(socket, error: gettext("Write something first."))}
    else
      params =
        Map.new([
          {:body, body},
          {:mentioned_user_ids, kept_mentions(body, socket.assigns.mentioned)},
          {socket.assigns.parent_key, socket.assigns.parent_id}
        ])

      case Comments.create_comment(params, scope: socket.assigns.scope) do
        {:ok, _comment} ->
          socket = assign(socket, draft: "", mentioned: %{}, suggestions: [], error: nil)
          {:noreply, assign(socket, comments: load_comments(socket.assigns))}

        {:error, _} ->
          {:noreply, assign(socket, error: gettext("Could not post that comment."))}
      end
    end
  end

  def handle_event("edit-comment", %{"id" => id}, socket) do
    {:noreply, assign(socket, editing_id: id)}
  end

  def handle_event("cancel-edit", _params, socket) do
    {:noreply, assign(socket, editing_id: nil)}
  end

  def handle_event("save-edit", %{"comment_id" => id, "body" => body}, socket) do
    body = String.trim(body)

    with false <- body == "",
         comment when not is_nil(comment) <- find(socket.assigns.comments, id),
         {:ok, _} <- Comments.update_comment(comment, %{body: body}, scope: socket.assigns.scope) do
      {:noreply,
       socket
       |> assign(editing_id: nil)
       |> assign(comments: load_comments(socket.assigns))}
    else
      _ -> {:noreply, assign(socket, editing_id: nil)}
    end
  end

  def handle_event("delete-comment", %{"id" => id}, socket) do
    with comment when not is_nil(comment) <- find(socket.assigns.comments, id),
         :ok <- Comments.delete_comment(comment, scope: socket.assigns.scope) do
      {:noreply, assign(socket, comments: load_comments(socket.assigns))}
    else
      _ -> {:noreply, socket}
    end
  end

  # --- data ---

  defp load_comments(assigns) do
    Comments.list_comments!(%{assigns.parent_key => assigns.parent_id}, scope: assigns.scope)
  end

  defp members(scope) do
    Accounts.list_user_organizations!(
      scope: scope,
      query: [filter: [organization_id: scope.organization.id, status: :active]],
      load: [user: [:email, profile: [:first_name, :last_name]]]
    )
    |> Enum.map(fn membership ->
      %{id: membership.user_id, name: author_name(membership.user)}
    end)
    |> Enum.uniq_by(& &1.id)
  end

  defp find(comments, id), do: Enum.find(comments, &(&1.id == id))

  defp own?(comment, scope), do: comment.author_id == scope.user.id

  # --- @mention handling ---

  defp active_query(draft) do
    case Regex.run(@mention_at_end, draft) do
      [_, query] -> query
      _ -> nil
    end
  end

  defp suggest(members, query) do
    q = String.downcase(query)

    members
    |> Enum.filter(&String.contains?(String.downcase(&1.name), q))
    |> Enum.take(@max_suggestions)
  end

  defp insert_mention(draft, name) do
    Regex.replace(@mention_at_end, draft, "") <> "@" <> name <> " "
  end

  # Keep only the mentions whose `@Name` still appears in the final body.
  defp kept_mentions(body, mentioned) do
    for {id, name} <- mentioned, String.contains?(body, "@" <> name), uniq: true, do: id
  end

  defp mentioned_names(comment, members) do
    by_id = Map.new(members, &{&1.id, &1.name})

    comment.mentioned_user_ids
    |> Enum.map(&Map.get(by_id, &1))
    |> Enum.reject(&is_nil/1)
  end

  # Render the body with `@Name` mentions wrapped as chips and everything else escaped
  # as plain text. Built as a raw string (not HEEx) to avoid any stray whitespace
  # around the chips.
  defp rendered_body(body, []), do: escape(body)

  defp rendered_body(body, names) do
    pattern = Enum.map_join(names, "|", &Regex.escape("@" <> &1))
    regex = Regex.compile!("(#{pattern})")
    mentions = MapSet.new(names, &("@" <> &1))

    regex
    |> Regex.split(body, include_captures: true, trim: true)
    |> Enum.map_join("", fn segment ->
      if MapSet.member?(mentions, segment) do
        ~s(<span class="rounded bg-brand-soft px-1 font-medium text-brand">) <>
          escape(segment) <> "</span>"
      else
        escape(segment)
      end
    end)
    |> Phoenix.HTML.raw()
  end

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

  # --- display ---

  defp author_name(%{profile: %{first_name: first, last_name: last}} = user) do
    case [first, last] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" ") do
      "" -> to_string(user.email)
      name -> name
    end
  end

  defp author_name(%{email: email}) when not is_nil(email), do: to_string(email)
  defp author_name(_), do: gettext("Former member")

  defp initials(name) do
    name
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join("", &String.slice(&1, 0, 1))
    |> String.upcase()
    |> case do
      "" -> "?"
      value -> value
    end
  end

  @avatar_colors ~w(bg-blue-500 bg-emerald-500 bg-violet-500 bg-amber-500 bg-rose-500 bg-cyan-500)
  defp avatar_color(nil), do: "bg-gray-400"

  defp avatar_color(id) do
    Enum.at(@avatar_colors, :erlang.phash2(id, length(@avatar_colors)))
  end

  defp time_ago(nil), do: ""

  defp time_ago(%DateTime{} = at) do
    seconds = DateTime.diff(DateTime.utc_now(), at, :second)

    cond do
      seconds < 60 -> gettext("just now")
      seconds < 3600 -> gettext("%{n}m ago", n: div(seconds, 60))
      seconds < 86_400 -> gettext("%{n}h ago", n: div(seconds, 3600))
      seconds < 604_800 -> gettext("%{n}d ago", n: div(seconds, 86_400))
      true -> Calendar.strftime(at, "%b %-d, %Y")
    end
  end
end
