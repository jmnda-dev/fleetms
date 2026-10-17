defmodule Fleetms.Accounts.Invitation.Senders.SendInvitationEmail do
  @moduledoc """
  Emails an invitation link to a prospective organization member. The plain token
  is passed in (it is never stored) and embedded in the accept URL.
  """
  use FleetmsWeb, :verified_routes

  import Swoosh.Email

  alias Fleetms.Mailer

  def send(invitation, token, organization_name) do
    opts = [
      title: "You're invited to #{organization_name}",
      intro:
        "You've been invited to join #{organization_name} on FleetMS. Click below to set up your account and accept.",
      button_label: "Accept invitation",
      url: url(~p"/invitations/#{token}"),
      note: "This invitation will expire in 7 days."
    ]

    new()
    |> from(Fleetms.Emails.from())
    |> to(to_string(invitation.email))
    |> subject("You've been invited to join #{organization_name} on FleetMS")
    |> html_body(Fleetms.Emails.action_email(opts))
    |> text_body(Fleetms.Emails.action_email_text(opts))
    |> Mailer.deliver!()
  end
end
