defmodule JsonWebToken.Jws do
  @moduledoc """
  Represent content to be secured with digital signatures or Message Authentication Codes (MACs)

  see http://tools.ietf.org/html/rfc7515
  """

  alias JsonWebToken.Format.Base64Url
  alias JsonWebToken.Jwa
  alias JsonWebToken.Util

  @signed_message_parts 3

  @doc """
  Return a JSON Web Signature (JWS), a string representing a digitally signed payload

  ## Example
      iex> key = "gZH75aKtMN3Yj0iPS4hcgUuTwjAzZr9C"
      ...> JsonWebToken.Jws.sign(%{alg: "HS256"}, "payload", key)
      "eyJhbGciOiJIUzI1NiJ9.cGF5bG9hZA.uVTaOdyzp_f4mT_hfzU8LnCzdmlVC4t2itHDEYUZym4"
  """
  def sign(header, payload, key) do
    alg = algorithm(header)
    signing_input = signing_input(header, payload)
    "#{signing_input}.#{signature(alg, key, signing_input)}"
  end

  defp algorithm(header) do
    Util.validate_present(header[:alg])
  end

  defp signing_input(header, payload) do
    "#{Base64Url.encode header_json(Poison.encode header)}.#{Base64Url.encode payload}"
  end

  defp header_json({:ok, json}), do: json
  defp header_json({:error, _}), do: raise "Failed to encode header as JSON"

  defp signature(algorithm, key, signing_input) do
    Base64Url.encode(Jwa.sign algorithm, key, signing_input)
  end

  @doc """
  Return a JWS string if the signature does verify, or an "Invalid" string otherwise

  ## Example
      iex> jws = "eyJhbGciOiJIUzI1NiJ9.cGF5bG9hZA.uVTaOdyzp_f4mT_hfzU8LnCzdmlVC4t2itHDEYUZym4"
      ...> key = "gZH75aKtMN3Yj0iPS4hcgUuTwjAzZr9C"
      ...> JsonWebToken.Jws.verify(jws, "HS256", key)
      "eyJhbGciOiJIUzI1NiJ9.cGF5bG9hZA.uVTaOdyzp_f4mT_hfzU8LnCzdmlVC4t2itHDEYUZym4"
  """
  def verify(jws, algorithm, key \\ nil) do
    validate_alg_matched(jws, algorithm)
    verified(jws, algorithm, key)
  end

  defp validate_alg_matched(jws, algorithm) do
    header = decoded_header_json_to_map(jws)
    alg_match(algorithm(header) === algorithm)
  end

  defp decoded_header_json_to_map(jws) do
    [head | _] = String.split(jws, ".")
    head
    |> Base64Url.decode
    |> Poison.decode(keys: :atoms)
    |> header_map
  end

  defp header_map({:ok, map}), do: map
  defp header_map({:error, _}), do: raise "Failed to decode header from JSON"

  defp alg_match(true), do: true
  defp alg_match(false), do: raise "Algorithm not matching 'alg' header parameter"

  defp verified(jws, algorithm, key) do
    verified_jws(jws, signature_verify?(parts_list(jws), algorithm, key))
  end

  defp verified_jws(jws, true), do: jws
  defp verified_jws(_, _), do: "Invalid"

  defp parts_list(jws), do: valid_parts_list(String.split jws, ".")

  defp valid_parts_list(parts) when length(parts) == @signed_message_parts, do: parts
  defp valid_parts_list(_), do: nil

  defp signature_verify?(nil, _, _), do: false
  defp signature_verify?(_, _, nil), do: false
  defp signature_verify?(parts, algorithm, key) do
    [header, message, signature] = parts
    Jwa.verify?(Base64Url.decode(signature), algorithm, key, "#{header}.#{message}")
  end
end