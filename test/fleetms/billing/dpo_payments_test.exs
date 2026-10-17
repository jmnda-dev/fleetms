defmodule Fleetms.Billing.DpoPaymentsTest do
  @moduledoc "DPO adapter + payment orchestration, with the provider HTTP stubbed."
  use Fleetms.DataCase, async: false
  use Oban.Testing, repo: Fleetms.Repo

  alias Fleetms.Billing
  alias Fleetms.Billing.Payments
  alias Fleetms.Billing.Providers.Dpo
  alias Fleetms.Billing.Workers.VerifyPayment

  setup :shared_org

  @stub Fleetms.Billing.Providers.DpoStub

  defp stub_dpo(xml), do: Req.Test.stub(@stub, fn conn -> Req.Test.text(conn, xml) end)

  defp create_ok_xml do
    ~s|<?xml version="1.0" encoding="utf-8"?><API3G><Result>000</Result><ResultExplanation>Created</ResultExplanation><TransToken>TESTTOKEN123</TransToken><TransRef>R1</TransRef></API3G>|
  end

  defp verify_xml(code) do
    ~s|<?xml version="1.0" encoding="utf-8"?><API3G><Result>#{code}</Result><ResultExplanation>Explanation #{code}</ResultExplanation></API3G>|
  end

  defp billing_fixture(org) do
    plan =
      Billing.create_plan!(
        %{
          code: "p-#{System.unique_integer([:positive])}",
          name: "P",
          price: Money.new(:ZMW, 500)
        },
        authorize?: false
      )

    sub =
      Billing.subscribe!(
        %{organization_id: org.id, plan_id: plan.id, provider: :dpo},
        authorize?: false
      )

    invoice =
      Billing.create_invoice!(
        %{organization_id: org.id, subscription_id: sub.id, amount_due: Money.new(:ZMW, 500)},
        authorize?: false
      )
      |> Billing.issue_invoice!(authorize?: false)

    payment =
      Billing.create_payment!(
        %{
          organization_id: org.id,
          invoice_id: invoice.id,
          subscription_id: sub.id,
          provider: :dpo,
          amount: Money.new(:ZMW, 500),
          customer_email: "customer@example.com"
        },
        authorize?: false
      )

    %{plan: plan, subscription: sub, invoice: invoice, payment: payment}
  end

  describe "Dpo.create_transaction/1" do
    test "returns a redirect handoff on Result 000", %{org: org} do
      stub_dpo(create_ok_xml())
      %{payment: payment} = billing_fixture(org)

      assert {:ok, handoff} = Dpo.create_transaction(payment)
      assert {:redirect, url} = handoff.action
      assert url =~ "payv3.php?ID=TESTTOKEN123"
      assert handoff.provider_reference == "TESTTOKEN123"
    end

    test "returns an error on a non-000 result", %{org: org} do
      stub_dpo(
        ~s|<?xml version="1.0"?><API3G><Result>904</Result><ResultExplanation>Currency not supported</ResultExplanation></API3G>|
      )

      %{payment: payment} = billing_fixture(org)

      assert {:error, {:dpo_error, "904", "Currency not supported"}} =
               Dpo.create_transaction(payment)
    end
  end

  describe "Payments.initiate/1" do
    test "records processing + checkout URL and schedules a verify", %{org: org} do
      stub_dpo(create_ok_xml())
      %{payment: payment} = billing_fixture(org)

      assert {:ok, payment} = Payments.initiate(payment)
      assert payment.status == :processing
      assert payment.checkout_url =~ "TESTTOKEN123"
      assert payment.provider_reference == "TESTTOKEN123"
      assert_enqueued(worker: VerifyPayment, args: %{payment_id: payment.id})
    end
  end

  describe "Payments.verify/1" do
    setup %{org: org} do
      stub_dpo(create_ok_xml())
      fixture = billing_fixture(org)
      {:ok, payment} = Payments.initiate(fixture.payment)
      Map.put(fixture, :payment, payment)
    end

    test "Result 000 succeeds and cascades to the invoice and subscription", ctx do
      stub_dpo(verify_xml("000"))

      assert {:ok, payment} = Payments.verify(ctx.payment)
      assert payment.status == :succeeded
      assert payment.paid_at

      assert Billing.get_invoice!(ctx.invoice.id, authorize?: false).status == :paid
      assert Billing.get_subscription!(ctx.subscription.id, authorize?: false).status == :active
    end

    test "Result 900 leaves the payment processing (still pending)", ctx do
      stub_dpo(verify_xml("900"))

      assert {:ok, payment} = Payments.verify(ctx.payment)
      assert payment.status == :processing
      assert Billing.get_invoice!(ctx.invoice.id, authorize?: false).status == :open
    end

    test "a declined code fails the payment", ctx do
      stub_dpo(verify_xml("901"))

      assert {:ok, payment} = Payments.verify(ctx.payment)
      assert payment.status == :failed
      assert payment.failure_reason =~ "901"
    end

    test "applying a result to an already-succeeded payment is a no-op", ctx do
      stub_dpo(verify_xml("000"))
      {:ok, succeeded} = Payments.verify(ctx.payment)

      assert {:ok, still} = Payments.apply_result(succeeded, %{status: :failed})
      assert still.status == :succeeded
    end
  end
end
