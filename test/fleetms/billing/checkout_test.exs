defmodule Fleetms.Billing.CheckoutTest do
  @moduledoc "The guarded subscribe-and-pay / pay-invoice entry point."
  use Fleetms.DataCase, async: false

  alias Fleetms.Billing
  alias Fleetms.Billing.Checkout

  @stub Fleetms.Billing.Providers.DpoStub

  setup :shared_org

  defp stub_dpo_ok do
    Req.Test.stub(@stub, fn conn ->
      Req.Test.text(
        conn,
        ~s|<?xml version="1.0"?><API3G><Result>000</Result><TransToken>TK1</TransToken></API3G>|
      )
    end)
  end

  defp plan_fixture do
    Billing.create_plan!(
      %{
        code: "c-#{System.unique_integer([:positive])}",
        name: "Fleet",
        price: Money.new(:ZMW, 500),
        price_per_vehicle: Money.new(:ZMW, 100),
        included_vehicles: 1
      },
      authorize?: false
    )
  end

  test "subscribe_and_pay (owner, DPO) creates the sub + invoice and initiates the payment",
       %{org: org, owner: owner} do
    stub_dpo_ok()
    plan = plan_fixture()

    assert {:ok, %{subscription: sub, invoice: invoice, payment: payment}} =
             Checkout.subscribe_and_pay(org, plan.id, 3, :dpo, owner)

    assert sub.status == :incomplete
    assert sub.quantity == 3
    assert sub.provider == :dpo

    assert invoice.status == :open
    # 500 base + 2 extra vehicles (3 - 1 included) × 100
    assert Money.equal?(invoice.amount_due, Money.new(:ZMW, 700))

    assert payment.status == :processing
    assert payment.checkout_url =~ "TK1"
    assert payment.invoice_id == invoice.id
  end

  test "a non-owner is forbidden", %{org: org} do
    plan = plan_fixture()
    stranger = user_fixture()

    assert {:error, :forbidden} = Checkout.subscribe_and_pay(org, plan.id, 1, :dpo, stranger)
  end

  test "pay_invoice starts a fresh payment for an open invoice", %{org: org, owner: owner} do
    stub_dpo_ok()
    plan = plan_fixture()
    {:ok, %{invoice: invoice}} = Checkout.subscribe_and_pay(org, plan.id, 1, :dpo, owner)

    assert {:ok, payment} = Checkout.pay_invoice(invoice, :dpo, owner)
    assert payment.status == :processing
    assert payment.invoice_id == invoice.id
  end
end
