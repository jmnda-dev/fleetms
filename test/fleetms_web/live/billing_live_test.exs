defmodule FleetmsWeb.BillingLiveTest do
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Fleetms.Billing
  alias Fleetms.Scope

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), org: org, scope: Scope.new(owner, org, true)}
  end

  test "the owner sees the billing page with the plan catalogue", %{conn: conn, org: org} do
    Billing.create_plan!(
      %{
        code: "starter-#{System.unique_integer([:positive])}",
        name: "Starter Plan",
        price: Money.new(:ZMW, 150)
      },
      authorize?: false
    )

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/billing")

    assert html =~ "Billing"
    assert html =~ "Choose a plan"
    assert html =~ "Starter Plan"
    assert html =~ "Invoices"
  end

  test "shows the current subscription once one exists", %{conn: conn, org: org} do
    plan =
      Billing.create_plan!(
        %{
          code: "fleet-#{System.unique_integer([:positive])}",
          name: "Fleet Plan",
          price: Money.new(:ZMW, 500)
        },
        authorize?: false
      )

    Billing.subscribe!(
      %{organization_id: org.id, plan_id: plan.id, provider: :dpo},
      authorize?: false
    )

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/billing")

    assert html =~ "Current plan"
    assert html =~ "Fleet Plan"
  end
end
