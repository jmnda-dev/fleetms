defmodule Fleetms.VehicleManagement.RenewalDigestTest do
  use Fleetms.DataCase, async: true

  import Fleetms.VehicleFixtures
  import Swoosh.TestAssertions

  alias Fleetms.VehicleManagement.RenewalDigest

  setup :shared_org

  defp tenant(org), do: "org_#{org.id}"

  test "emails the owner a digest of due-soon/overdue renewals", %{
    scope: scope,
    org: org,
    owner: owner
  } do
    vehicle = vehicle_fixture(scope, %{name: "Digest-#{System.unique_integer([:positive])}"})

    overdue =
      vehicle_renewal_fixture(scope, %{
        vehicle_id: vehicle.id,
        due_date: Date.add(Date.utc_today(), -3)
      })

    assert {:ok, 1} = RenewalDigest.deliver_for_tenant(tenant(org))

    assert_email_sent(fn email ->
      assert {_, to} = hd(email.to)
      assert to == to_string(owner.email)
      assert email.subject =~ "renewal"
      assert email.html_body =~ vehicle.name
      assert email.html_body =~ "Overdue"
      # silence unused
      overdue.id
    end)
  end

  test "sends nothing when no renewals are due", %{scope: scope, org: org} do
    # Far-future due date → Upcoming, not in the digest.
    vehicle_renewal_fixture(scope, %{due_date: Date.add(Date.utc_today(), 300)})

    assert {:ok, 0} = RenewalDigest.deliver_for_tenant(tenant(org))
    assert_no_email_sent()
  end
end
