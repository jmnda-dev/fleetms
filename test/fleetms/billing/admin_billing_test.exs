defmodule Fleetms.Billing.AdminBillingTest do
  @moduledoc "Entitlement notices and staff manual settlement."
  use Fleetms.DataCase, async: false

  alias Fleetms.Billing
  alias Fleetms.Billing.{Checkout, Entitlement}

  setup :shared_org

  defp plan_fixture do
    Billing.create_plan!(
      %{
        code: "c-#{System.unique_integer([:positive])}",
        name: "Fleet",
        price: Money.new(:ZMW, 500)
      },
      authorize?: false
    )
  end

  defp subscription(org, status) do
    sub =
      Billing.subscribe!(
        %{organization_id: org.id, plan_id: plan_fixture().id},
        authorize?: false
      )

    case status do
      :incomplete ->
        sub

      :active ->
        Billing.activate_subscription!(sub, authorize?: false)

      :past_due ->
        sub
        |> Billing.activate_subscription!(authorize?: false)
        |> Billing.mark_subscription_past_due!(authorize?: false)

      :expired ->
        sub
        |> Billing.activate_subscription!(authorize?: false)
        |> Billing.expire_subscription!(authorize?: false)
    end
  end

  describe "Entitlement.notice_for_organization/1" do
    test "nil when there's no subscription", %{org: org} do
      assert Entitlement.notice_for_organization(org.id) == nil
    end

    test "nil when active", %{org: org} do
      subscription(org, :active)
      assert Entitlement.notice_for_organization(org.id) == nil
    end

    test ":past_due and :expired are surfaced", %{org: org} do
      subscription(org, :past_due)
      assert Entitlement.notice_for_organization(org.id) == :past_due
    end
  end

  describe "Checkout.mark_invoice_paid_manually/2" do
    setup %{org: org} do
      sub = subscription(org, :incomplete)

      invoice =
        Billing.create_invoice!(
          %{organization_id: org.id, subscription_id: sub.id, amount_due: Money.new(:ZMW, 500)},
          authorize?: false
        )
        |> Billing.issue_invoice!(authorize?: false)

      %{subscription: sub, invoice: invoice}
    end

    test "staff settlement marks the invoice paid and activates the subscription",
         %{invoice: invoice, subscription: sub} do
      staff = user_fixture() |> then(&Ash.Seed.update!(&1, %{is_super_admin: true}))

      assert {:ok, payment} = Checkout.mark_invoice_paid_manually(invoice, staff)
      assert payment.provider == :manual
      assert payment.status == :succeeded

      assert Billing.get_invoice!(invoice.id, authorize?: false).status == :paid
      assert Billing.get_subscription!(sub.id, authorize?: false).status == :active
    end

    test "a non-staff actor is forbidden", %{invoice: invoice} do
      assert {:error, :forbidden} = Checkout.mark_invoice_paid_manually(invoice, user_fixture())
    end
  end
end
