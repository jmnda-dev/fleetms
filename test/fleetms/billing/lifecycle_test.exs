defmodule Fleetms.Billing.LifecycleTest do
  @moduledoc "The periodic subscription sweep: dunning and expiry."
  use Fleetms.DataCase, async: false

  alias Fleetms.Billing
  alias Fleetms.Billing.Lifecycle

  setup :shared_org

  defp active_sub(org, quantity \\ 1) do
    plan =
      Billing.create_plan!(
        %{
          code: "c-#{System.unique_integer([:positive])}",
          name: "Fleet",
          interval: :month,
          price: Money.new(:ZMW, 500)
        },
        authorize?: false
      )

    Billing.subscribe!(
      %{organization_id: org.id, plan_id: plan.id, quantity: quantity},
      authorize?: false
    )
    |> Billing.activate_subscription!(authorize?: false)
  end

  defp days_after(datetime, days), do: DateTime.add(datetime, days * 86_400, :second)

  defp reload(sub), do: Billing.get_subscription!(sub.id, authorize?: false)

  defp open_renewals(org, sub) do
    org.id
    |> Billing.list_organization_invoices!(authorize?: false)
    |> Enum.count(&(&1.subscription_id == sub.id and &1.status == :open))
  end

  test "an active subscription past its period lapses to past_due with a renewal invoice",
       %{org: org} do
    sub = active_sub(org)

    Lifecycle.run(days_after(sub.current_period_end, 2))

    sub = reload(sub)
    assert sub.status == :past_due
    assert open_renewals(org, sub) == 1
  end

  test "an active subscription still within its period is untouched", %{org: org} do
    sub = active_sub(org)

    Lifecycle.run(days_after(sub.current_period_end, -5))

    assert reload(sub).status == :active
    assert open_renewals(org, sub) == 0
  end

  test "a past_due subscription beyond the grace window expires", %{org: org} do
    sub = active_sub(org) |> Billing.mark_subscription_past_due!(authorize?: false)

    # grace_days default is 7
    Lifecycle.run(days_after(sub.current_period_end, 10))

    assert reload(sub).status == :expired
  end

  test "a past_due subscription within the grace window stays past_due", %{org: org} do
    sub = active_sub(org) |> Billing.mark_subscription_past_due!(authorize?: false)

    Lifecycle.run(days_after(sub.current_period_end, 3))

    assert reload(sub).status == :past_due
  end

  test "a second sweep doesn't create a duplicate renewal invoice", %{org: org} do
    sub = active_sub(org)
    as_of = days_after(sub.current_period_end, 2)

    Lifecycle.run(as_of)
    Lifecycle.run(as_of)

    assert open_renewals(org, reload(sub)) == 1
  end
end
