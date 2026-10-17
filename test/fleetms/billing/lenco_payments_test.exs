defmodule Fleetms.Billing.LencoPaymentsTest do
  @moduledoc "Lenco adapter (virtual-account pay-in + signed webhook) and orchestration."
  use Fleetms.DataCase, async: false
  use Oban.Testing, repo: Fleetms.Repo

  alias Fleetms.Billing
  alias Fleetms.Billing.Payments
  alias Fleetms.Billing.Providers.Lenco
  alias Fleetms.Billing.Workers.VerifyPayment

  @stub Fleetms.Billing.Providers.LencoStub
  @token "TEST-LENCO-TOKEN"

  setup :shared_org

  defp stub_lenco(data) do
    Req.Test.stub(@stub, fn conn -> Req.Test.json(conn, %{"status" => true, "data" => data}) end)
  end

  defp va_data(reference) do
    %{
      "id" => "va_1",
      "accountReference" => "AR-1",
      "currency" => "ZMW",
      "expiresAt" => "2026-10-02T00:00:00Z",
      "bankAccount" => %{
        "accountNumber" => "1234567890",
        "accountName" => "FleetMS subscription",
        "bank" => %{"name" => "Lenco MFB", "code" => "999"}
      },
      "meta" => %{"transactionReference" => reference}
    }
  end

  defp sign(body) do
    key = :sha256 |> :crypto.hash(@token) |> Base.encode16(case: :lower)
    :hmac |> :crypto.mac(:sha512, key, body) |> Base.encode16(case: :lower)
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
        %{organization_id: org.id, plan_id: plan.id, provider: :lenco},
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
          provider: :lenco,
          amount: Money.new(:ZMW, 500)
        },
        authorize?: false
      )

    %{subscription: sub, invoice: invoice, payment: payment}
  end

  describe "create_transaction/1" do
    test "returns pay-in instructions and the provider reference", %{org: org} do
      %{payment: payment} = billing_fixture(org)
      stub_lenco(va_data(payment.reference))

      assert {:ok, handoff} = Lenco.create_transaction(payment)
      assert {:instructions, instructions} = handoff.action
      assert instructions["account_number"] == "1234567890"
      assert instructions["bank_name"] == "Lenco MFB"
      assert handoff.provider_reference == "va_1"
      assert handoff.method == :bank_transfer
    end
  end

  describe "Payments.initiate/1 (webhook-confirmed)" do
    test "records instructions and does NOT schedule a verify job", %{org: org} do
      %{payment: payment} = billing_fixture(org)
      stub_lenco(va_data(payment.reference))

      assert {:ok, payment} = Payments.initiate(payment)
      assert payment.status == :processing
      assert payment.instructions["account_number"] == "1234567890"
      refute_enqueued(worker: VerifyPayment)
    end
  end

  describe "parse_webhook/2" do
    test "accepts a correctly signed credit event and extracts our reference", %{org: org} do
      %{payment: payment} = billing_fixture(org)

      body =
        Jason.encode!(%{
          "event" => "virtual-account.transaction",
          "data" => %{"id" => "txn_1", "transactionReference" => payment.reference}
        })

      assert {:ok, result} = Lenco.parse_webhook(%{"x-lenco-signature" => sign(body)}, body)
      assert result.status == :succeeded
      assert result.reference == payment.reference
    end

    test "rejects a bad signature" do
      body = Jason.encode!(%{"event" => "virtual-account.transaction", "data" => %{}})

      assert {:error, :invalid_signature} =
               Lenco.parse_webhook(%{"x-lenco-signature" => "deadbeef"}, body)
    end

    test "ignores events we don't handle (signature valid)" do
      body = Jason.encode!(%{"event" => "account.balance-updated", "data" => %{}})

      assert {:error, :event_ignored} =
               Lenco.parse_webhook(%{"x-lenco-signature" => sign(body)}, body)
    end
  end

  describe "Payments.handle_webhook/3" do
    test "settles the payment and cascades to invoice + subscription", ctx do
      %{payment: payment, invoice: invoice, subscription: subscription} = billing_fixture(ctx.org)

      body =
        Jason.encode!(%{
          "event" => "virtual-account.transaction.settled",
          "data" => %{"id" => "txn_2", "transactionReference" => payment.reference}
        })

      assert {:ok, settled} =
               Payments.handle_webhook(:lenco, %{"x-lenco-signature" => sign(body)}, body)

      assert settled.status == :succeeded
      assert Billing.get_invoice!(invoice.id, authorize?: false).status == :paid
      assert Billing.get_subscription!(subscription.id, authorize?: false).status == :active
    end

    test "returns :payment_not_found for an unknown reference" do
      body =
        Jason.encode!(%{
          "event" => "virtual-account.transaction",
          "data" => %{"transactionReference" => "PMT-nope"}
        })

      assert {:error, :payment_not_found} =
               Payments.handle_webhook(:lenco, %{"x-lenco-signature" => sign(body)}, body)
    end
  end
end
