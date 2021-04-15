defmodule Macaroon.Verification do
  alias Macaroon.Types
  alias Types.Verification.VerifyError
  alias Types.Verification.VerifyParameters
  alias Types.Verification.VerifyContext

  alias Macaroon.Util.Crypto

  @spec verify(
          Macaroon.Types.Verification.VerifyParameters.t(),
          Macaroon.Types.Macaroon.t(),
          binary,
          maybe_improper_list
        ) ::
          {:error, Macaroon.Types.Verification.VerifyContext.t()}
          | {:ok, Macaroon.Types.Verification.VerifyContext.t()}
  def verify(%VerifyParameters{} = verification_params, %Types.Macaroon{} = macaroon, key, discharge_macaroons \\ []) when is_binary(key) and is_list(discharge_macaroons) do
    derived_key = Crypto.create_derived_key(key)
    ctx = VerifyContext.build(
      key: derived_key,
      calculated_signature: nil,
      parameters: verification_params,
      discharges: discharge_macaroons
    )

    %VerifyContext{} = result = verify_discharge(macaroon, macaroon, ctx)

    if length(result.errors) > 0 do
      {:error, result}
    else
      {:ok, result}
    end
  end

  @spec satisfy_general(fun) :: struct
  def satisfy_general(callback) when is_function(callback) do
    VerifyParameters.build(
      callback: [callback]
    )
  end

  def satisfy_exact(predicate) when is_binary(predicate) do
    VerifyParameters.build(
      predicates: [predicate]
    )
  end

  @spec satisfy_general(Macaroon.Types.Verification.VerifyParameters.t(), fun) ::
          Macaroon.Types.Verification.VerifyParameters.t()
  def satisfy_general(%VerifyParameters{} = verification_context, callback) when is_function(callback) do
    %VerifyParameters{verification_context | callbacks: [callback | verification_context.callbacks]}
  end

  @spec satisfy_exact(Macaroon.Types.Verification.VerifyParameters.t(), binary) ::
          Macaroon.Types.Verification.VerifyParameters.t()
  def satisfy_exact(%VerifyParameters{} = verification_context, predicate) when is_binary(predicate) do
    %VerifyParameters{verification_context | predicates: [predicate | verification_context.predicates]}
  end

  defp verify_discharge(%Types.Macaroon{} = root_macaroon, %Types.Macaroon{} = macaroon, %VerifyContext{} = ctx) do
    sig = :crypto.hmac(:sha256, ctx.key, macaroon.public_identifier)
    ctx = %VerifyContext{ctx | calculated_signature: sig}
    |> verify_all_caveats(macaroon)

    if root_macaroon != macaroon do
      key = Crypto.truncate_or_pad_string(<<0>>, :enacl.secretbox_KEYBYTES)
      new_sig = Crypto.hmac_concat(key, root_macaroon.signature, ctx.calculated_signature)
      %VerifyContext{ctx | calculated_signature: new_sig}
    else
      ctx
    end
  end

  defp verify_all_caveats(%VerifyContext{} = ctx, %Types.Macaroon{} = macaroon) do
    ctx
    |> verify_first_party_caveats(macaroon)
    |> verify_third_party_caveats(macaroon)
  end

  defp verify_first_party_caveats(%VerifyContext{} = ctx, %Types.Macaroon{} = macaroon) do
    Enum.reduce(macaroon.first_party_caveats, ctx, fn caveat, ctx -> do_verify_first_party_caveat(caveat, ctx) end)
  end

  defp verify_third_party_caveats(%VerifyContext{} = ctx, %Types.Macaroon{} = macaroon) do
    Enum.reduce(macaroon.third_party_caveats, ctx, fn caveat, ctx -> do_verify_third_party_caveat(caveat, macaroon, ctx) end)
  end

  defp do_verify_first_party_caveat(%Types.Caveat{} = caveat, %VerifyContext{} = ctx) do
    params = ctx.parameters
    is_met = cond do
      Enum.member?(params.predicates, caveat.caveat_id) -> true
      Enum.find(params.callbacks, false, fn cb -> cb.(caveat.caveat_id) == true end) -> true
      :else -> false
    end

    if is_met do
      sig = :crypto.hmac(:sha256, ctx.calculated_signature, caveat.caveat_id)
      %VerifyContext{ctx | calculated_signature: sig}
    else
      error = VerifyError.build(
        type: :caveat_not_met,
        details: "caveat `#{caveat.caveat_id}` was not met"
      )
      %VerifyContext{ctx | errors: [error | ctx.errors]}
    end
  end

  defp do_verify_third_party_caveat(%Types.Caveat{} = caveat, %Types.Macaroon{} = macaroon, %VerifyContext{} = ctx) do
    discharge_macaroon = Enum.find(ctx.discharges, fn %Types.Macaroon{} = m -> m.public_identifier == caveat.caveat_id end)

    with %Types.Macaroon{} = caveat_macaroon <- discharge_macaroon do
      caveat_key = extract_caveat_key(ctx.calculated_signature, caveat)
      tmp_ctx = %VerifyContext{ctx | key: caveat_key}
      is_met = verify_discharge(macaroon, caveat_macaroon, tmp_ctx)

      if is_met do
        sig = Crypto.hmac_concat(ctx.calculated_signature, caveat.verification_key_id, caveat.caveat_id)
        %VerifyContext{ctx | calculated_signature: sig}
      else

      end
    else
      _ ->
        error = VerifyError.build(
          type: :discharge_not_found,
          details: "caveat `#{caveat.caveat_id}` was not met, no discharge macaroon found"
        )
        %VerifyContext{ctx | errors: [error | ctx.errors]}
    end
  end

  defp extract_caveat_key(signature, %Types.Caveat{} = caveat) do
    key = Crypto.truncate_or_pad_string(signature)
    {nonce, cipher_text} = String.split_at(caveat.verification_key_id, :enacl.secretbox_NONCEBYTES)
    case :enacl.secretbox_open(cipher_text, nonce, key) do
      {:ok, msg} -> msg
      _ -> <<0>>
    end
  end
end
