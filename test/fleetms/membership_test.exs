defmodule Fleetms.MembershipTest do
  # Not async: each test provisions a real organization tenant schema (DDL);
  # running these concurrently can deadlock on the shared migration locks.
  use Fleetms.DataCase, async: false

  require Ash.Query

  alias Fleetms.Accounts.{Role, User, UserRole}
  alias Fleetms.Membership

  setup do
    {owner, org} = user_with_org_fixture()
    # Discard the owner's registration confirmation email so tests only see the
    # emails they trigger.
    flush_emails()
    %{owner: owner, org: org}
  end

  describe "create_member_with_username/3" do
    test "an owner can provision a username-only member who can then sign in",
         %{owner: owner, org: org} do
      username = "tech_#{System.unique_integer([:positive])}"

      assert {:ok, user} =
               Membership.create_member_with_username(
                 %{
                   username: username,
                   password: "password1234",
                   password_confirmation: "password1234",
                   profile: %{first_name: "Sam"}
                 },
                 org,
                 owner
               )

      assert user.username == username
      assert is_nil(user.email)

      # They are an active member of the org.
      {:ok, members} = Membership.list_members(org, owner)
      assert user.id in Enum.map(members, & &1.user_id)

      # And can sign in with their username.
      strategy = AshAuthentication.Info.strategy!(User, :username_password)

      assert {:ok, _} =
               AshAuthentication.Strategy.action(strategy, :sign_in, %{
                 "username" => username,
                 "password" => "password1234"
               })
    end

    test "a member without manage_users cannot provision users", %{org: org} do
      # A plain member with no roles/permissions.
      stranger = user_fixture()

      Fleetms.Accounts.add_user_to_organization!(
        %{user_id: stranger.id, organization_id: org.id},
        authorize?: false
      )

      assert {:error, :forbidden} =
               Membership.create_member_with_username(
                 %{
                   username: "x_#{System.unique_integer([:positive])}",
                   password: "password1234",
                   password_confirmation: "password1234",
                   profile: %{first_name: "No"}
                 },
                 org,
                 stranger
               )
    end
  end

  describe "invite_member/3" do
    test "adds an existing account immediately", %{owner: owner, org: org} do
      existing = user_fixture()

      assert {:ok, :added, membership} =
               Membership.invite_member(%{email: to_string(existing.email)}, org, owner)

      assert membership.user_id == existing.id
      assert membership.status == :active
    end

    test "assigns the given role when adding an existing account", %{owner: owner, org: org} do
      existing = user_fixture()
      role = system_role("Read Only", org)

      assert {:ok, :added, _membership} =
               Membership.invite_member(
                 %{email: to_string(existing.email), role_id: role.id},
                 org,
                 owner
               )

      # Regression: this used to be silently dropped (assigned with a nil actor,
      # which the :assign_user_roles policy forbade).
      assert role_assigned?(existing.id, role.id, org)
    end

    test "emails an invitation when no account exists", %{owner: owner, org: org} do
      email = "invitee-#{System.unique_integer([:positive])}@example.com"

      assert {:ok, :invited, invitation} =
               Membership.invite_member(%{email: email}, org, owner)

      assert to_string(invitation.email) == email
      assert invitation.status == :pending

      assert_received {:email, sent}
      assert Enum.any?(sent.to, fn {_name, addr} -> addr == email end)
    end

    test "a username-only user cannot be added to another org by email (portability)",
         %{owner: owner, org: org} do
      # Provision a username-only user in a *different* org.
      {other_owner, other_org} = user_with_org_fixture()
      username = "driver_#{System.unique_integer([:positive])}"

      {:ok, _user} =
        Membership.create_member_with_username(
          %{
            username: username,
            password: "password1234",
            password_confirmation: "password1234",
            profile: %{first_name: "Drive"}
          },
          other_org,
          other_owner
        )

      # They have no email, so there's nothing to invite them by — inviting a made
      # up email just creates a brand-new invitation, never linking the username user.
      assert {:ok, :invited, _} =
               Membership.invite_member(%{email: "#{username}@example.com"}, org, owner)
    end
  end

  describe "accept_invitation/2" do
    test "creates the account and active membership", %{owner: owner, org: org} do
      email = "invitee-#{System.unique_integer([:positive])}@example.com"
      {:ok, :invited, _invitation} = Membership.invite_member(%{email: email}, org, owner)
      token = capture_invitation_token()

      assert {:ok, user} =
               Membership.accept_invitation(token, %{
                 password: "password1234",
                 password_confirmation: "password1234",
                 profile: %{first_name: "Joiner"}
               })

      assert to_string(user.email) == email
      refute is_nil(user.confirmed_at)

      {:ok, members} = Membership.list_members(org, owner)
      assert user.id in Enum.map(members, & &1.user_id)
    end

    test "a used or unknown token is rejected", %{owner: _owner, org: _org} do
      assert {:error, _} =
               Membership.accept_invitation("not-a-real-token", %{
                 password: "password1234",
                 password_confirmation: "password1234",
                 profile: %{first_name: "Nope"}
               })
    end
  end

  describe "suspend / reactivate" do
    test "an owner can suspend and reactivate a member", %{owner: owner, org: org} do
      member = add_plain_member(org)

      assert {:ok, suspended} = Membership.suspend_member(member, org, owner)
      assert suspended.status == :suspended

      assert {:ok, reactivated} = Membership.reactivate_member(suspended, org, owner)
      assert reactivated.status == :active
    end

    test "the last owner cannot be suspended", %{owner: owner, org: org} do
      owner_membership = owner_membership(org, owner)
      assert {:error, {:cannot, _}} = Membership.suspend_member(owner_membership, org, owner)
    end
  end

  describe "remove_member/3" do
    test "an owner can remove a member", %{owner: owner, org: org} do
      member = add_plain_member(org)

      assert {:ok, _} = Membership.remove_member(member, org, owner)

      {:ok, members} = Membership.list_members(org, owner)
      refute member.user_id in Enum.map(members, & &1.user_id)
    end

    test "the last owner cannot be removed", %{owner: owner, org: org} do
      owner_membership = owner_membership(org, owner)
      assert {:error, {:cannot, _}} = Membership.remove_member(owner_membership, org, owner)
    end

    test "you cannot remove yourself", %{owner: owner, org: org} do
      # Even with a second owner present, self-removal is blocked.
      second = user_fixture()

      Fleetms.Accounts.add_user_to_organization!(
        %{user_id: second.id, organization_id: org.id, owner?: true},
        authorize?: false
      )

      owner_membership = owner_membership(org, owner)
      assert {:error, {:cannot, _}} = Membership.remove_member(owner_membership, org, owner)
    end
  end

  # --- helpers ---

  defp add_plain_member(org) do
    user = user_fixture()

    Fleetms.Accounts.add_user_to_organization!(
      %{user_id: user.id, organization_id: org.id},
      authorize?: false
    )
  end

  defp owner_membership(org, owner) do
    {:ok, members} = Membership.list_members(org, owner)
    Enum.find(members, &(&1.user_id == owner.id))
  end

  defp capture_invitation_token do
    assert_received {:email, sent}
    [_, token] = Regex.run(~r{/invitations/([^"\s<]+)}, sent.html_body)
    token
  end

  defp flush_emails do
    receive do
      {:email, _} -> flush_emails()
    after
      0 -> :ok
    end
  end

  defp system_role(name, org) do
    Role
    |> Ash.Query.filter(name == ^name and is_system == true)
    |> Ash.read_one!(authorize?: false, tenant: org)
  end

  defp role_assigned?(user_id, role_id, org) do
    UserRole
    |> Ash.Query.filter(user_id == ^user_id and role_id == ^role_id)
    |> Ash.read!(authorize?: false, tenant: org)
    |> Enum.any?()
  end
end
