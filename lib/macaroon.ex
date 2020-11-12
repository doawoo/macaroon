defmodule Macaroon do
  alias Macaroon.Types
  alias Macaroon.Util

  @key_gen_string "macaroons-key-generator"

  @spec create_macaroon(binary, binary, binary) :: Types.Macaroon.t()
  def create_macaroon(location, public_ident, secret)
      when is_binary(location) and is_binary(public_ident) and is_binary(secret) do
    inital_sig = :crypto.hmac(:sha256, secret, public_ident)

    Types.Macaroon.build(
      location: location,
      public_identifier: public_ident,
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

  @spec add_third_party_caveat(Macaroon.Types.Macaroon.t(), binary, binary, binary) ::
          Macaroon.Types.Macaroon.t()
  def add_third_party_caveat(%Types.Macaroon{} = macaroon, location, caveat_key, caveat_predicate)
      when is_binary(location) and is_binary(caveat_predicate) and is_binary(caveat_key) do
    derived_key = :crypto.hmac(:sha256, caveat_key, @key_gen_string)
    old_key = Util.truncate_or_pad_string(macaroon.signature)
    nonce = :crypto.strong_rand_bytes(32)
    verification_key_id = :enacl.secretbox(derived_key, nonce, old_key)

    c =
      Types.Caveat.build(
        caveat_id: caveat_predicate,
        location: location,
        verification_key_id: verification_key_id,
        party: :third
      )

    hash_a = :crypto.hmac(:sha256, macaroon.signature, verification_key_id)
    hash_b = :crypto.hmac(:sha256, macaroon.signature, caveat_predicate)
    concat_digest = :crypto.hmac(:sha256, macaroon.signature, hash_a <> hash_b)

    %Types.Macaroon{
      macaroon
      | signature: concat_digest,
        third_party_caveats: [c | macaroon.third_party_caveats]
    }
  end
end
