defmodule FleetmsWeb.Billing.LencoWebhookControllerTest do
  use FleetmsWeb.ConnCase, async: false

  alias Fleetms.Billing

  @token "TEST-LENCO-TOKEN"

  setup :shared_org

  defp sign(body) do
    key = :sha256 |> :crypto.hash(@token) |> Base.encode16(case: :lower)
    :hmac |> :crypto.mac(:sha512, key, body) |> Base.encode16(case: :lower)
  end

  defp processing_payment(org) do
    Billing.create_payment!(
      %{organization_id: org.id, provider: :lenco, amount: Money.new(:ZMW, 300)},
      authorize?: false
    )
    |> Billing.start_payment_processing!(
      %{provider_reference: "va_9", instructions: %{"account_number" => "1"}},
      authorize?: false
    )
  end

  defp post_webhook(conn, body, signature) do
    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("x-lenco-signature", signature)
    |> post(~p"/billing/webhooks/lenco", body)
  end

  test "a correctly signed credit event settles the payment and acks 200", %{conn: conn, org: org} do
    payment = processing_payment(org)

    body =
      Jason.encode!(%{
        "event" => "virtual-account.transaction",
        "data" => %{"id" => "txn_5", "transactionReference" => payment.reference}
      })

    conn = post_webhook(conn, body, sign(body))

    assert response(conn, 200)
    assert Billing.get_payment!(payment.id, authorize?: false).status == :succeeded
  end

  test "a bad signature is rejected with 401 and leaves the payment untouched", %{
    conn: conn,
    org: org
  } do
    payment = processing_payment(org)

    body =
      Jason.encode!(%{
        "event" => "virtual-account.transaction",
        "data" => %{"transactionReference" => payment.reference}
      })

    conn = post_webhook(conn, body, "not-a-valid-signature")

    assert response(conn, 401)
    assert Billing.get_payment!(payment.id, authorize?: false).status == :processing
  end

  test "an unknown reference is acknowledged with 200 (no retries)", %{conn: conn} do
    body =
      Jason.encode!(%{
        "event" => "virtual-account.transaction",
        "data" => %{"transactionReference" => "PMT-unknown"}
      })

    conn = post_webhook(conn, body, sign(body))

    assert response(conn, 200)
  end
end
