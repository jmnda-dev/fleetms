defmodule Fleetms.Notifications.NotificationTest do
  use Fleetms.DataCase, async: true

  import Fleetms.NotificationFixtures

  alias Fleetms.Notifications

  setup :shared_org

  describe "notify / list" do
    test "creates a notification addressed to the recipient", %{scope: scope, owner: owner} do
      assert {:ok, notification} =
               Notifications.notify(
                 %{recipient_id: owner.id, type: "issue_assigned", title: "You were assigned #5"},
                 scope: scope
               )

      assert notification.recipient_id == owner.id
      assert notification.title == "You were assigned #5"
      assert is_nil(notification.read_at)
    end

    test "lists the recipient's notifications newest first", %{scope: scope} do
      a = notification_fixture(scope, %{title: "First-#{uniq()}"})
      b = notification_fixture(scope, %{title: "Second-#{uniq()}"})

      assert {:ok, list} = Notifications.list_notifications(scope: scope)
      ids = Enum.map(list, & &1.id)
      # Both present, and the newer one comes first.
      assert b.id in ids and a.id in ids
      assert Enum.find_index(ids, &(&1 == b.id)) < Enum.find_index(ids, &(&1 == a.id))
    end
  end

  describe "read state" do
    test "mark_read stamps read_at", %{scope: scope} do
      notification = notification_fixture(scope)

      assert {:ok, read} = Notifications.mark_notification_read(notification, scope: scope)
      assert read.read_at
    end

    test "unread_count reflects only unread", %{scope: scope} do
      notification_fixture(scope)
      to_read = notification_fixture(scope)
      Notifications.mark_notification_read!(to_read, scope: scope)

      assert {:ok, count} = Notifications.unread_notification_count(scope: scope)
      assert count >= 1
      refute_count_includes_read(scope, to_read)
    end

    test "mark_all_read clears every unread and returns the count", %{scope: scope} do
      notification_fixture(scope)
      notification_fixture(scope)

      assert {:ok, n} = Notifications.mark_all_notifications_read(scope: scope)
      assert n >= 2
      assert {:ok, 0} = Notifications.unread_notification_count(scope: scope)
    end
  end

  describe "real-time broadcast" do
    test "creating a notification broadcasts on the recipient's topic", %{
      scope: scope,
      org: org,
      owner: owner
    } do
      topic = Fleetms.Notifications.topic("org_#{org.id}", owner.id)
      Phoenix.PubSub.subscribe(Fleetms.PubSub, topic)

      notification_fixture(scope, %{recipient_id: owner.id})

      assert_receive :notifications_changed
    end
  end

  defp refute_count_includes_read(scope, read_notification) do
    {:ok, unread} = Notifications.list_unread_notifications(scope: scope)
    refute read_notification.id in Enum.map(unread, & &1.id)
  end

  defp uniq, do: System.unique_integer([:positive])
end
