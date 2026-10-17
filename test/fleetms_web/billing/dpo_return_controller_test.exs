defmodule FleetmsWeb.Billing.DpoReturnControllerTest do
  use FleetmsWeb.ConnCase, async: false

  alias Fleetms.Billing

  @stub Fleetms.Billing.Providers.DpoStub

  setup :shared_org

  defp stub_dpo(xml), do: Req.Test.stub(@stub, fn conn -> Req.Test.text(conn, xml) end)

  defp processing_payment(org) do
    Billing.create_payment!(
      %{organization_id: org.id, provider: :dpo, amount: Money.new(:ZMW, 300)},
      authorize?: false
    )
    |> Billing.start_payment_processing!(
      %{provider_reference: "TOK-1", checkout_url: "https://x"},
      authorize?: false
    )
  end

  test "verifies the transaction and shows success on return", %{conn: conn, org: org} do
    payment = processing_payment(org)

    stub_dpo(
      ~s|<?xml version="1.0"?><API3G><Result>000</Result><ResultExplanation>Paid</ResultExplanation></API3G>|
    )

    conn = get(conn, ~p"/billing/pay/dpo/return?CompanyRef=#{payment.reference}")

    assert html_response(conn, 200) =~ "Payment received"
    assert Billing.get_payment!(payment.id, authorize?: false).status == :succeeded
  end

  test "shows an unknown-status page for an unmatched reference", %{conn: conn} do
    conn = get(conn, ~p"/billing/pay/dpo/return?CompanyRef=does-not-exist")
    assert html_response(conn, 200) =~ "unknown"
  end
end
