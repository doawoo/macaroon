defmodule Macaroon do
  alias Macaroon.Types
  alias Macaroon.Util

  @spec create_macaroon(binary, binary, binary) :: Types.Macaroon.t()
  def create_macaroon(location, public_identifier, secret)
      when is_binary(location) and is_binary(public_identifier) and is_binary(secret) do
    derived_key = Util.Crypto.create_derived_key(secret)
    inital_sig = :crypto.hmac(:sha256, derived_key, public_identifier)

    Types.Macaroon.build(
      location: location,
      public_identifier: public_identifier,
      signature: inital_sig
    )
  end

  @spec add_first_party_caveat(Macaroon.Types.Macaroon.t(), binary) :: Macaroon.Types.Macaroon.t()
  def add_first_party_caveat(%Types.Macaroon{} = macaroon, caveat_predicate)
      when is_binary(caveat_predicate) do
    c =
      Types.Caveat.build(
        caveat_id: caveat_predicate,
        party: :first
      )

    new_sig = :crypto.hmac(:sha256, macaroon.signature, caveat_predicate)

    %Types.Macaroon{
      macaroon
      | signature: new_sig,
        first_party_caveats: [c | macaroon.first_party_caveats]
    }
  end

  def add_third_party_caveat(%Types.Macaroon{} = macaroon, location, caveat_id, caveat_key, nonce \\ nil)
      when is_binary(location) and is_binary(caveat_id) and is_binary(caveat_key) do
    derived_key = caveat_key
    |> Util.Crypto.create_derived_key()
    |> Util.Crypto.truncate_or_pad_string()

    old_key = Util.Crypto.truncate_or_pad_string(macaroon.signature, :enacl.secretbox_KEYBYTES)

    nonce = nonce || :crypto.strong_rand_bytes(:enacl.secretbox_NONCEBYTES)

    verification_key_id = nonce <> :enacl.secretbox(derived_key, nonce, old_key)

    c =
      Types.Caveat.build(
        caveat_id: caveat_id,
        location: location,
        verification_key_id: verification_key_id,
        party: :third
      )

    concat_digest = Util.Crypto.hmac_concat(macaroon.signature, verification_key_id, caveat_id)

    %Types.Macaroon{
      macaroon
      | signature: concat_digest,
        third_party_caveats: [c | macaroon.third_party_caveats]
    }
  end
end
