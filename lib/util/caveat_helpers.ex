defmodule Macaroon.Util.CaveatHelpers do
  alias Macaroon.Types

  @spec add_rsa_third_party_caveat(
          Macaroon.Types.Macaroon.t(),
          binary,
          binary,
          :RSAPublicKey.t(),
          non_neg_integer
        ) :: Macaroon.Types.Macaroon.t()
  @doc """
  This is a convenience method to help you create RSA public-key encrypted third-party caveats.
  You would use this when you have a well-known public key from the third-party server you wish to sent the
  caveate to.

  This method also takes care of generating a random nonce for the verification portion of the caveat.
  """
  def add_rsa_third_party_caveat(
        %Types.Macaroon{} = macaroon,
        location,
        predicate,
        public_key,
        nonce_len \\ 32
      ) do
    third_party_ckey = :crypto.strong_rand_bytes(nonce_len)
    message = "#{third_party_ckey}#{predicate}"
    encrypted_predicate = :public_key.encrypt_public(message, public_key, [])

    Macaroon.add_third_party_caveat(macaroon, location, encrypted_predicate, third_party_ckey)
  end

  @spec decrypt_rsa_third_party_caveat(
          Macaroon.Types.Caveat.t(),
          :RSAPrivateKey.t(),
          non_neg_integer
        ) :: {binary, binary}
  @doc """
  This is a convenience method to help you decrypt a third-party caveat that has been encrypted by a RSA public key
  Provided you know the private key, and length of the nonce you can unpack the cipher text into the 2 components: `{discharge_root_key, predicate_to_validate}`

  If you do NOT know the nonce length it will simply return the decrypted cipher text.
  """
  def decrypt_rsa_third_party_caveat(
        %Types.Caveat{caveat_id: cipher_text, party: :third},
        private_key,
        nonce_length
      ) do
    decrypted = :public_key.decrypt_private(cipher_text, private_key)
    discharge_key = :binary.part(decrypted, 0, nonce_length)
    predicate = :binary.part(decrypted, nonce_length, byte_size(decrypted) - nonce_length)
    {discharge_key, predicate}
  end

  @spec decrypt_rsa_third_party_caveat(
          Macaroon.Types.Caveat.t(),
          :RSAPrivateKey.t()
        ) :: binary
  def decrypt_rsa_third_party_caveat(
        %Types.Caveat{caveat_id: cipher_text, party: :third},
        private_key
      ) do
    :public_key.decrypt_private(cipher_text, private_key)
  end
end
