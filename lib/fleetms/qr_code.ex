defmodule Fleetms.QRCode do
  @moduledoc """
  Thin wrapper over `EQRCode` that returns an inline-ready SVG string.

  The library prepends an XML prolog (`<?xml …?>`), which isn't valid inside an
  HTML document, so it's stripped — leaving a bare `<svg>…</svg>` that can be
  rendered with `raw/1`.
  """

  @doc "An SVG QR code for `data`, ready to embed inline in a page."
  @spec svg(String.t(), keyword()) :: String.t()
  def svg(data, opts \\ []) when is_binary(data) do
    width = Keyword.get(opts, :width, 220)

    data
    |> EQRCode.encode()
    |> EQRCode.svg(width: width, background_color: "#FFF", color: "#000")
    |> strip_prolog()
  end

  defp strip_prolog(svg) do
    case String.split(svg, "?>", parts: 2) do
      [_prolog, rest] -> String.trim_leading(rest)
      [only] -> only
    end
  end
end
