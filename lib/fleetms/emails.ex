defmodule Fleetms.Emails do
  @moduledoc """
  Branded transactional email bodies.

  Emails must be inline-styled, table-based HTML to render across mail clients,
  so these are built as strings (no HEEx/layout machinery). `action_email/1`
  produces the standard shape we use for every auth email — a wordmark header, a
  heading, a short intro, one primary call-to-action button, a copy-paste
  fallback link, an optional note, and a footer — centered in a 600px card that
  collapses cleanly on mobile.
  """

  # Brand palette (hex, since email clients need inline colors).
  @brand "#3b53a4"
  @ink "#111827"
  @muted "#6b7280"
  @bg "#f3f4f6"
  @card "#ffffff"

  @default_from {"FleetMS", "noreply@fleetms.example"}

  @doc "The From tuple for outgoing mail (override with config :fleetms, :email_from)."
  def from, do: Application.get_env(:fleetms, :email_from, @default_from)

  @doc """
  A branded action email. Options: `:title`, `:intro`, `:button_label`, `:url`,
  and optional `:note`. Returns an HTML string.
  """
  def action_email(opts) do
    url = opts[:url]
    note = opts[:note]

    content = """
    <h1 style="margin:0 0 12px;font-size:20px;font-weight:700;color:#{@ink};">#{esc(opts[:title])}</h1>
    <p style="margin:0 0 24px;font-size:15px;line-height:1.6;color:#{@muted};">#{esc(opts[:intro])}</p>
    <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 0 24px;">
      <tr><td style="border-radius:8px;background:#{@brand};">
        <a href="#{url}" style="display:inline-block;padding:12px 28px;font-size:15px;font-weight:600;color:#ffffff;text-decoration:none;border-radius:8px;">#{esc(opts[:button_label])}</a>
      </td></tr>
    </table>
    <p style="margin:0 0 8px;font-size:13px;color:#{@muted};">Or paste this link into your browser:</p>
    <p style="margin:0 0 4px;font-size:13px;word-break:break-all;"><a href="#{url}" style="color:#{@brand};">#{esc(url)}</a></p>
    #{note_html(note)}
    """

    layout(content)
  end

  @doc """
  The plain-text companion to `action_email/1` (same options). Mail clients and spam
  filters prefer a multipart message with a text alternative, so every transactional
  email should set both `html_body` and this as `text_body`.
  """
  def action_email_text(opts) do
    note = opts[:note]

    [
      opts[:title],
      "",
      opts[:intro],
      "",
      "#{opts[:button_label]}: #{opts[:url]}",
      "",
      "If the link above doesn't work, copy and paste it into your browser.",
      if(note, do: "\n#{note}", else: nil),
      "",
      "— FleetMS · Fleet Maintenance & Management",
      "If you weren't expecting this email, you can safely ignore it."
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp note_html(nil), do: ""

  defp note_html(note),
    do: ~s(<p style="margin:24px 0 0;font-size:13px;color:#{@muted};">#{esc(note)}</p>)

  defp layout(content) do
    """
    <!DOCTYPE html>
    <html lang="en">
      <head><meta charset="utf-8" /><meta name="viewport" content="width=device-width,initial-scale=1" /></head>
      <body style="margin:0;padding:0;background:#{@bg};">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#{@bg};padding:24px 12px;">
          <tr><td align="center">
            <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="width:100%;max-width:600px;">
              <tr><td style="padding:8px 8px 20px;">
                <span style="font-size:20px;font-weight:800;letter-spacing:-0.02em;color:#{@brand};">FleetMS</span>
              </td></tr>
              <tr><td style="background:#{@card};border-radius:12px;padding:32px;">
                #{content}
              </td></tr>
              <tr><td style="padding:20px 8px;font-size:12px;color:#{@muted};">
                FleetMS — Fleet Maintenance &amp; Management. If you weren't expecting this email, you can safely ignore it.
              </td></tr>
            </table>
          </td></tr>
        </table>
      </body>
    </html>
    """
  end

  @doc """
  HTML-escapes a value for safe interpolation into an email HTML body. Use this for
  any user-supplied text (vehicle/part/org names, titles, assignee names, etc.) in
  the hand-built HTML digests, the same way `action_email/1` escapes its own inputs.
  """
  def escape(nil), do: ""
  def escape(value), do: value |> to_string() |> Plug.HTML.html_escape()

  defp esc(value), do: escape(value)
end
