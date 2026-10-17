defmodule Fleetms.Storage.S3.ReqClient do
  @moduledoc """
  An `ExAws` HTTP client backed by `Req`.

  We already depend on Req, so this lets `ex_aws` reuse it instead of pulling in
  hackney (which also conflicts with our `idna` version). Configured globally via
  `config :ex_aws, :http_client, Fleetms.Storage.S3.ReqClient`.
  """
  @behaviour ExAws.Request.HttpClient

  @impl true
  def request(method, url, body, headers, _http_opts) do
    case Req.request(
           method: method,
           url: url,
           headers: headers,
           body: body,
           decode_body: false,
           retry: false
         ) do
      {:ok, %Req.Response{status: status, headers: resp_headers, body: resp_body}} ->
        {:ok, %{status_code: status, headers: flatten(resp_headers), body: resp_body}}

      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end

  # Req returns headers as a map of name => [values]; ExAws expects a flat list.
  defp flatten(headers) do
    Enum.flat_map(headers, fn
      {key, values} when is_list(values) -> Enum.map(values, &{key, &1})
      {key, value} -> [{key, value}]
    end)
  end
end
