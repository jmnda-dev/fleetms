defmodule Fleetms.Billing.Providers.Dpo do
  @moduledoc """
  DPO Pay (v6) adapter — a redirect/hosted-checkout provider.

  Flow: `createToken` returns a `TransToken`; we send the customer to the hosted
  checkout (`<checkout_url>?ID=<TransToken>`, card + mobile money). DPO returns the
  customer to our `RedirectURL`/`BackURL`, and `verifyToken` (Result `000` = paid)
  is the source of truth — used both by the return handler and the Oban verify job.

  DPO's single endpoint speaks XML. Credentials come from
  `config :fleetms, Fleetms.Billing, dpo: [...]` (a sandbox company token is the dev
  default; production reads `DPO_COMPANY_TOKEN` / `DPO_SERVICE_TYPE` from the env).
  """
  @behaviour Fleetms.Billing.PaymentProvider

  import SweetXml, only: [sigil_x: 2]

  alias Fleetms.Billing.Payment

  @impl true
  def confirmation_mode, do: :verify

  @impl true
  def create_transaction(%Payment{} = payment) do
    cfg = config()
    xml = create_token_xml(payment, cfg)

    with {:ok, body} <- post(xml, cfg),
         {:ok, %{result: "000", trans_token: token}} <- parse_create(body) do
      {:ok,
       %{
         action: {:redirect, "#{cfg[:checkout_url]}?ID=#{token}"},
         provider_reference: token,
         raw_request: %{"xml" => xml},
         raw_response: %{"xml" => body}
       }}
    else
      {:ok, %{result: code, explanation: explanation}} ->
        {:error, {:dpo_error, code, explanation}}

      {:error, _} = error ->
        error
    end
  end

  @impl true
  def verify_transaction(%Payment{provider_reference: token} = _payment) when is_binary(token) do
    cfg = config()
    xml = verify_token_xml(token, cfg)

    with {:ok, body} <- post(xml, cfg) do
      {result, explanation} = parse_verify(body)

      {:ok,
       %{
         status: status_for(result),
         provider_reference: token,
         failure_reason: if(status_for(result) == :failed, do: explanation),
         raw: %{"xml" => body}
       }}
    end
  end

  def verify_transaction(%Payment{}), do: {:error, :no_provider_reference}

  # DPO confirms via the browser return + verifyToken, not a signed webhook.
  @impl true
  def parse_webhook(_headers, _raw_body), do: {:error, :unsupported}

  # --- HTTP ---

  defp post(xml, cfg) do
    options =
      [
        body: xml,
        headers: [{"content-type", "application/xml"}, {"accept", "application/xml"}]
      ] ++ Application.get_env(:fleetms, :dpo_req_options, [])

    case Req.post(cfg[:base_url], options) do
      {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) -> {:ok, body}
      {:ok, %Req.Response{status: status}} -> {:error, {:dpo_http_status, status}}
      {:error, reason} -> {:error, {:dpo_transport, reason}}
    end
  end

  # --- XML build ---

  defp create_token_xml(%Payment{} = payment, cfg) do
    return_url = FleetmsWeb.Endpoint.url() <> "/billing/pay/dpo/return"

    """
    <?xml version="1.0" encoding="utf-8"?>
    <API3G>
      <CompanyToken>#{cfg[:company_token]}</CompanyToken>
      <Request>createToken</Request>
      <Transaction>
        <PaymentAmount>#{amount_string(payment.amount)}</PaymentAmount>
        <PaymentCurrency>#{currency_string(payment.amount)}</PaymentCurrency>
        <CompanyRef>#{esc(payment.reference)}</CompanyRef>
        <RedirectURL>#{esc(return_url)}</RedirectURL>
        <BackURL>#{esc(return_url)}</BackURL>
        <customerEmail>#{esc(payment.customer_email)}</customerEmail>
        <customerPhone>#{esc(payment.customer_phone)}</customerPhone>
      </Transaction>
      <Services>
        <Service>
          <ServiceType>#{cfg[:service_type]}</ServiceType>
          <ServiceDescription>FleetMS subscription</ServiceDescription>
          <ServiceDate>#{service_date()}</ServiceDate>
        </Service>
      </Services>
    </API3G>
    """
  end

  defp verify_token_xml(token, cfg) do
    """
    <?xml version="1.0" encoding="utf-8"?>
    <API3G>
      <CompanyToken>#{cfg[:company_token]}</CompanyToken>
      <Request>verifyToken</Request>
      <TransactionToken>#{esc(token)}</TransactionToken>
    </API3G>
    """
  end

  # --- XML parse ---

  defp parse_create(body) do
    result = xget(body, ~x"//API3G/Result/text()"s)
    token = xget(body, ~x"//API3G/TransToken/text()"s)
    explanation = xget(body, ~x"//API3G/ResultExplanation/text()"s)

    if result == "000" and token != "" do
      {:ok, %{result: result, trans_token: token}}
    else
      {:ok, %{result: result, explanation: explanation}}
    end
  rescue
    _ -> {:error, :dpo_unparseable_response}
  end

  defp parse_verify(body) do
    {xget(body, ~x"//API3G/Result/text()"s), xget(body, ~x"//API3G/ResultExplanation/text()"s)}
  rescue
    _ -> {"", "unparseable response"}
  end

  # DPO verify codes: 000 = paid; 900 = created but not yet paid; anything else is
  # treated as a terminal failure (declined/mismatch/etc.).
  defp status_for("000"), do: :succeeded
  defp status_for("900"), do: :pending
  defp status_for(_), do: :failed

  # --- helpers ---

  defp config, do: Application.get_env(:fleetms, Fleetms.Billing, [])[:dpo] || []

  defp amount_string(%Money{amount: amount}),
    do: amount |> Decimal.round(2) |> Decimal.to_string()

  defp currency_string(%Money{currency: currency}), do: Atom.to_string(currency)

  defp service_date, do: Calendar.strftime(DateTime.utc_now(), "%Y/%m/%d %H:%M")

  defp xget(body, path), do: body |> SweetXml.xpath(path) |> to_string() |> String.trim()

  defp esc(nil), do: ""

  defp esc(value) do
    value
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end
end
