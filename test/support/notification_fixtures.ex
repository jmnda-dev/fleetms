defmodule Fleetms.NotificationFixtures do
  @moduledoc "Test fixtures for the notifications domain."
  alias Fleetms.Notifications

  def notification_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        recipient_id: attrs[:recipient_id] || scope.user.id,
        title: "Note #{System.unique_integer([:positive])}"
      })

    Notifications.notify!(attrs, scope: scope)
  end
end
