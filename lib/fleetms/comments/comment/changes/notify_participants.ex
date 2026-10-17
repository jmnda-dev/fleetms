defmodule Fleetms.Comments.Comment.Changes.NotifyParticipants do
  @moduledoc """
  After a comment is created, notify the people who should hear about it: everyone
  `@mentioned` and the parent record's participants (assignee, reporter, …), minus
  the author. Mentioned members get a "mentioned you" notification; other
  participants get a "commented on" one.

  Runs `after_transaction` and is best-effort — a notification failure must never
  roll back the comment itself.
  """
  use Ash.Resource.Change

  alias Fleetms.Comments.Commentable

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_transaction(changeset, fn
      _changeset, {:ok, comment} ->
        notify(comment, context)
        {:ok, comment}

      _changeset, other ->
        other
    end)
  end

  defp notify(comment, context) do
    opts = [tenant: context.tenant, authorize?: false]

    %{label: label, path: path, participant_ids: participant_ids} =
      Commentable.resolve(comment, opts)

    author_id = comment.author_id
    author_name = author_name(context.actor)
    mentioned = comment.mentioned_user_ids |> Enum.reject(&is_nil/1) |> MapSet.new()
    body = excerpt(comment.body)

    (comment.mentioned_user_ids ++ participant_ids)
    |> Enum.reject(&(is_nil(&1) or &1 == author_id))
    |> Enum.uniq()
    |> Enum.each(fn recipient_id ->
      {type, title} =
        if MapSet.member?(mentioned, recipient_id) do
          {"comment_mention", "#{author_name} mentioned you on #{label}"}
        else
          {"comment", "#{author_name} commented on #{label}"}
        end

      Fleetms.Notifications.notify_if_subscribed(
        %{
          recipient_id: recipient_id,
          actor_id: author_id,
          type: type,
          title: title,
          body: body,
          path: path
        },
        opts
      )
    end)

    :ok
  end

  defp author_name(actor), do: profile_name(actor) || email_name(actor) || "A member"

  defp profile_name(%{profile: %{first_name: first, last_name: last}}) do
    case [first, last] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" ") do
      "" -> nil
      name -> name
    end
  end

  defp profile_name(_), do: nil

  defp email_name(%{email: email}) when not is_nil(email), do: to_string(email)
  defp email_name(_), do: nil

  defp excerpt(body) do
    body = String.trim(body)
    if String.length(body) > 140, do: String.slice(body, 0, 139) <> "…", else: body
  end
end
