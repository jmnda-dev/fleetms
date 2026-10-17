defmodule Fleetms.BillingTest do
  @moduledoc "Lifecycle and access tests for the platform billing model."
  use Fleetms.DataCase

  alias Fleetms.Billing

  setup :shared_org

  defp plan_fixture(attrs \\ %{}) do
    Billing.create_plan!(
      Map.merge(
        %{
          code: "plan-#{System.unique_integer([:positive])}",
          name: "Test Plan",
          price: Money.new(:ZMW, 250)
        },
        attrs
      ),
      authorize?: false
    )
  end

  describe "plans" do
    test "list_active_plans returns only active, public plans, cheapest first" do
      cheap = plan_fixture(%{price: Money.new(:ZMW, 100)})
      pricey = plan_fixture(%{price: Money.new(:ZMW, 900)})
      hidden = plan_fixture(%{public?: false})
      inactive = plan_fixture(%{active?: false})

      ids = Billing.list_active_plans!(authorize?: false) |> Enum.map(& &1.id)

      assert cheap.id in ids
      assert pricey.id in ids
      refute hidden.id in ids
      refute inactive.id in ids
      assert Enum.find_index(ids, &(&1 == cheap.id)) < Enum.find_index(ids, &(&1 == pricey.id))
    end

    test "code must be unique" do
      plan = plan_fixture()

      assert {:error, _} =
               Billing.create_plan(
                 %{code: plan.code, name: "Dup", price: Money.new(:ZMW, 1)},
                 authorize?: false
               )
    end
  end

  describe "subscription lifecycle" do
    test "subscribe → activate → renew advances the period and entitles", %{org: org} do
      plan = plan_fixture(%{interval: :month})

      sub = Billing.subscribe!(%{organization_id: org.id, plan_id: plan.id}, authorize?: false)
      assert sub.status == :incomplete
      assert is_nil(sub.current_period_end)

      sub =
        sub
        |> Billing.activate_subscription!(authorize?: false)
        |> Ash.load!(:active_now?, authorize?: false)

      assert sub.status == :active
      assert sub.active_now?
      assert sub.current_period_start
      assert sub.started_at
      first_end = sub.current_period_end
      assert DateTime.diff(first_end, sub.current_period_start, :day) in 28..31

      sub = Billing.renew_subscription!(sub, authorize?: false)
      assert sub.status == :active
      assert DateTime.after?(sub.current_period_end, first_end)
    end

    test "renew is rejected unless the subscription is active", %{org: org} do
      plan = plan_fixture()
      sub = Billing.subscribe!(%{organization_id: org.id, plan_id: plan.id}, authorize?: false)

      assert {:error, _} = Billing.renew_subscription(sub, authorize?: false)
    end

    test "cancel stamps canceled_at and drops entitlement", %{org: org} do
      plan = plan_fixture()

      sub =
        Billing.subscribe!(%{organization_id: org.id, plan_id: plan.id}, authorize?: false)
        |> Billing.activate_subscription!(authorize?: false)
        |> Billing.cancel_subscription!(authorize?: false)
        |> Ash.load!(:active_now?, authorize?: false)

      assert sub.status == :canceled
      assert sub.canceled_at
      refute sub.active_now?
    end
  end

  describe "invoices" do
    test "create (draft) assigns a number → issue → mark_paid", %{org: org} do
      inv =
        Billing.create_invoice!(
          %{
            organization_id: org.id,
            amount_due: Money.new(:ZMW, 500),
            description: "One month",
            line_items: [
              %{
                description: "Test Plan",
                quantity: 1,
                unit_amount: Money.new(:ZMW, 500),
                amount: Money.new(:ZMW, 500)
              }
            ]
          },
          authorize?: false
        )

      assert inv.status == :draft
      assert inv.number =~ ~r/^INV-\d{6}$/
      assert [%{description: "Test Plan"}] = inv.line_items

      inv = Billing.issue_invoice!(inv, authorize?: false)
      assert inv.status == :open
      assert inv.issued_at

      inv = Billing.mark_invoice_paid!(inv, authorize?: false)
      assert inv.status == :paid
      assert inv.paid_at
      assert Money.equal?(inv.amount_paid, inv.amount_due)
    end
  end

  describe "payments" do
    test "create → processing → succeed", %{org: org} do
      pay =
        Billing.create_payment!(
          %{organization_id: org.id, provider: :dpo, amount: Money.new(:ZMW, 500)},
          authorize?: false
        )

      assert pay.status == :pending
      assert pay.reference =~ ~r/^PMT-/

      pay =
        Billing.start_payment_processing!(
          pay,
          %{provider_reference: "T1", checkout_url: "https://secure.example/pay", method: :card},
          authorize?: false
        )

      assert pay.status == :processing
      assert pay.checkout_url == "https://secure.example/pay"

      pay = Billing.succeed_payment!(pay, %{provider_reference: "T1"}, authorize?: false)
      assert pay.status == :succeeded
      assert pay.paid_at
    end

    test "an illegal state transition is rejected", %{org: org} do
      pay =
        Billing.create_payment!(
          %{organization_id: org.id, provider: :dpo, amount: Money.new(:ZMW, 500)},
          authorize?: false
        )
        |> Billing.succeed_payment!(%{}, authorize?: false)

      # Cannot go back to processing from succeeded.
      assert {:error, _} = Billing.start_payment_processing(pay, %{}, authorize?: false)
    end
  end

  describe "authorization" do
    test "the org owner can read its subscription; an unrelated user cannot", %{
      org: org,
      owner: owner
    } do
      plan = plan_fixture()
      sub = Billing.subscribe!(%{organization_id: org.id, plan_id: plan.id}, authorize?: false)

      assert {:ok, %{id: id}} = Billing.get_subscription(sub.id, actor: owner)
      assert id == sub.id

      stranger = user_fixture()
      assert {:error, _} = Billing.get_subscription(sub.id, actor: stranger)
    end
  end
end
