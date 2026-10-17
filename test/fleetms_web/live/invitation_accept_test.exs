defmodule FleetmsWeb.InvitationAcceptTest do
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Fleetms.Accounts
  alias Fleetms.Membership

  defp invite(org, owner) do
    # Discard the owner's registration confirmation email so we capture the
    # invitation email below.
    flush_emails()
    email = "invitee-#{System.unique_integer([:positive])}@example.com"
    {:ok, :invited, _invitation} = Membership.invite_member(%{email: email}, org, owner)

    assert_received {:email, sent}
    [_, token] = Regex.run(~r{/invitations/([^"\s<]+)}, sent.html_body)
    %{email: email, token: token}
  end

  defp flush_emails do
    receive do
      {:email, _} -> flush_emails()
    after
      0 -> :ok
    end
  end

  describe "accepting an invitation" do
    setup do
      {owner, org} = user_with_org_fixture()
      Map.merge(%{owner: owner, org: org}, invite(org, owner))
    end

    test "renders the setup form for a valid token", %{conn: conn, token: token, email: email} do
      {:ok, _view, html} = live(conn, ~p"/invitations/#{token}")
      assert html =~ "Accept your invitation"
      assert html =~ email
    end

    test "creates the account and membership, then sends to sign in",
         %{conn: conn, token: token, email: email, org: org, owner: owner} do
      {:ok, view, _html} = live(conn, ~p"/invitations/#{token}")

      result =
        view
        |> form("form",
          signup: %{
            first_name: "Pat",
            last_name: "Jones",
            password: "password1234",
            password_confirmation: "password1234"
          }
        )
        |> render_submit()

      assert {:error, {:live_redirect, %{to: "/sign-in"}}} = result

      # The account now exists and is an active member.
      assert {:ok, user} = Accounts.get_user_by_email(email, authorize?: false)
      refute is_nil(user.confirmed_at)
      {:ok, members} = Membership.list_members(org, owner)
      assert user.id in Enum.map(members, & &1.user_id)
    end
  end

  test "shows an error for an invalid token", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/invitations/not-a-real-token")
    assert html =~ "Invitation not found"
  end
end
