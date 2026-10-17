defmodule FleetmsWeb.Billing.DpoReturnController do
  @moduledoc """
  Handles the customer's return from DPO's hosted checkout. DPO redirects back with
  our `CompanyRef` (the payment reference); we verify the transaction with DPO
  (`verifyToken` is the source of truth), apply the result, and show a short
  confirmation page.

  This is a deliberately minimal placeholder page — the real billing UI (with a
  proper return-to-app flow) arrives in a later change.
  """
  use FleetmsWeb, :controller

  alias Fleetms.Billing
  alias Fleetms.Billing.Payments

  def show(conn, params) do
    status =
      with ref when is_binary(ref) <- params["CompanyRef"],
           {:ok, payment} <- Billing.get_payment_by_reference(ref, authorize?: false),
           {:ok, settled} <- Payments.verify(payment) do
        settled.status
      else
        _ -> :unknown
      end

    {code, title, message} = outcome(status)

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(code, page(title, message))
  end

  defp outcome(:succeeded),
    do: {200, "Payment received", "Thank you — your payment has been confirmed."}

  defp outcome(status) when status in [:pending, :processing],
    do:
      {200, "Payment pending",
       "We haven't received confirmation yet. If you completed payment, it will update shortly."}

  defp outcome(:failed),
    do: {200, "Payment not completed", "The payment didn't go through. You can try again."}

  defp outcome(_),
    do:
      {200, "Payment status unknown",
       "We couldn't match this payment. If you were charged, please contact support."}

  defp page(title, message) do
    """
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>#{title} · FleetMS</title>
      <style>
        body { font-family: system-ui, sans-serif; background: #f8fafc; color: #0f172a;
               display: grid; place-items: center; min-height: 100vh; margin: 0; }
        .card { background: #fff; border: 1px solid #e2e8f0; border-radius: 12px;
                padding: 2rem; max-width: 26rem; text-align: center;
                box-shadow: 0 1px 3px rgba(0,0,0,.08); }
        h1 { font-size: 1.25rem; margin: 0 0 .5rem; }
        p { color: #475569; margin: 0 0 1.25rem; }
        a { display: inline-block; background: #001a72; color: #fff; text-decoration: none;
            padding: .625rem 1.25rem; border-radius: 8px; font-weight: 600; }
      </style>
    </head>
    <body>
      <div class="card">
        <h1>#{title}</h1>
        <p>#{message}</p>
        <a href="/">Return to FleetMS</a>
      </div>
    </body>
    </html>
    """
  end
end
