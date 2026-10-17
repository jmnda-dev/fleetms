defmodule FleetmsWeb.DashboardBillingBannerTest do
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Fleetms.Billing

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), org: org}
  end

  defp past_due_subscription(org) do
    plan =
      Billing.create_plan!(
        %{
          code: "p-#{System.unique_integer([:positive])}",
          name: "Fleet",
          price: Money.new(:ZMW, 500)
        },
        authorize?: false
      )

    Billing.subscribe!(%{organization_id: org.id, plan_id: plan.id}, authorize?: false)
    |> Billing.activate_subscription!(authorize?: false)
    |> Billing.mark_subscription_past_due!(authorize?: false)
  end

  test "no banner when the subscription is healthy / absent", %{conn: conn, org: org} do
    {:ok, _view, html} = live(conn, ~p"/o/#{org}")
    refute html =~ "payment is due"
    refute html =~ "subscription has expired"
  end

  test "shows a dunning banner to the owner when past due", %{conn: conn, org: org} do
    past_due_subscription(org)

    {:ok, _view, html} = live(conn, ~p"/o/#{org}")

    assert html =~ "A payment is due" or html =~ "payment is due"
    assert html =~ "Go to billing"
  end
end
