defmodule Fleetms.Html do
  @moduledoc """
  Sanitization for user-authored rich text (the Tiptap WYSIWYG editor output).

  The editor produces HTML on the client, which is untrusted. Every value that
  comes from a `<.rich_text>` field is run through `sanitize/1` before it is
  stored, and rendered with `raw/1` only after sanitizing. This strips scripts,
  event handlers and other XSS vectors while keeping the formatting tags the
  editor can produce (headings, lists, links, emphasis, blockquote, code).

  Use this anywhere editor HTML crosses a trust boundary — typically in an Ash
  change on the action that accepts the field.
  """

  @doc """
  Sanitizes a rich-text HTML string with the permissive HTML5 allowlist.

  Returns `nil` for `nil`, and an empty string for blank/whitespace-only input
  so empty editors persist as empty rather than `<p></p>`.
  """
  @spec sanitize(String.t() | nil) :: String.t() | nil
  def sanitize(nil), do: nil

  def sanitize(html) when is_binary(html) do
    if blank_html?(html) do
      ""
    else
      HtmlSanitizeEx.html5(html)
    end
  end

  # Treats an editor that only emitted empty paragraphs / whitespace as blank.
  defp blank_html?(html) do
    html
    |> HtmlSanitizeEx.strip_tags()
    |> String.replace(~r/[[:space:]\x{00a0}]/u, "")
    |> Kernel.==("")
  end
end
