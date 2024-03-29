defmodule Macaroon do
  @moduledoc """
  This is the primary public interface for Elixir Macaroons
  """

  alias Macaroon.Types
  alias Macaroon.Util

  alias Macaroon.Serializers.Binary
  alias Macaroon.Serializers.JSON

  @doc """
  Create an empty Macaroon with a provided `location`, `public_id` and `secret`
  """
  @spec create_macaroon(binary, binary, binary) :: Types.Macaroon.t()
  def create_macaroon(location, public_identifier, secret)
      when is_binary(location) and is_binary(public_identifier) and is_binary(secret) do
    derived_key = Util.Crypto.create_derived_key(secret)
    initial_sig = :crypto.mac(:hmac, :sha256, derived_key, public_identifier)

    Types.Macaroon.build(
      location: location,
      public_identifier: public_identifier,
      signature: initial_sig
    )
  end

  @doc """
  Add a first-party caveat to a Macaroon provided a `predicate`
  """
  @spec add_first_party_caveat(Macaroon.Types.Macaroon.t(), binary) :: Macaroon.Types.Macaroon.t()
  def add_first_party_caveat(%Types.Macaroon{} = macaroon, predicate)
      when is_binary(predicate) do
    c =
      Types.Caveat.build(
        caveat_id: predicate,
        party: :first
      )

    new_sig = :crypto.mac(:hmac, :sha256, macaroon.signature, predicate)

    %Types.Macaroon{
      macaroon
      | signature: new_sig,
        caveats: macaroon.caveats ++ [c]
    }
  end

  @doc """
  Add a third-party caveat to a Macaroon provided a `location`, `predicate`, and random secret `caveat_key`

  `location` is a hint to where the client must go to prove this caveat

  `predicate` is a string that contains `caveat_key` and the predicate we want to have this caveat assert
  you should encrypt this in such a way that only the other party can decrypt it (pub/priv keys)

  OR

  retreieve an ID from the other service first and use that as the ID.

  `caveat_key` is the freshly generated secret key that will be encrypted using the current signature of the Macaroon

  `nonce` - you SHOULD NOT override this unless you know what you're doing (it defaults to secure random bytes)
  it is used when encrypting the `caveat_key` and should never be static unless you are testing something that requires
  the signature to be static.
  """
  @spec add_third_party_caveat(
          Macaroon.Types.Macaroon.t(),
          binary,
          binary,
          binary,
          false | nil | binary
        ) :: Macaroon.Types.Macaroon.t()
  def add_third_party_caveat(
        %Types.Macaroon{} = macaroon,
        location,
        predicate,
        caveat_key,
        nonce \\ nil
      )
      when is_binary(location) and is_binary(predicate) and is_binary(caveat_key) do
    derived_key =
      caveat_key
      |> Util.Crypto.create_derived_key()
      |> Util.Crypto.truncate_or_pad_string()

    old_key = Util.Crypto.truncate_or_pad_string(macaroon.signature, :enacl.secretbox_KEYBYTES())

    nonce = nonce || :crypto.strong_rand_bytes(:enacl.secretbox_NONCEBYTES())

    cipher_text = :enacl.secretbox(derived_key, nonce, old_key)

    verification_key_id = nonce <> cipher_text

    c =
      Types.Caveat.build(
        caveat_id: predicate,
        location: location,
        verification_key_id: verification_key_id,
        party: :third
      )

    concat_digest = Util.Crypto.hmac_concat(macaroon.signature, verification_key_id, predicate)

    %Types.Macaroon{
      macaroon
      | signature: concat_digest,
        caveats: macaroon.caveats ++ [c]
    }
  end

  @doc """
  This prepares a Macaroon for delegation to another third-party authorization service.
  Returns a "protected" (or bound) discharge Macaroon.

  `discharge_macaroon` - The Macaroon that will be sent back to the originating service

  `macaroon` - The Macaroon that the `discharge_macaroon` will be bound to. (The "root" Macaroon)
  """
  @spec prepare_for_request(Macaroon.Types.Macaroon.t(), Macaroon.Types.Macaroon.t()) ::
          Macaroon.Types.Macaroon.t()
  def prepare_for_request(%Types.Macaroon{} = discharge_macaroon, %Types.Macaroon{} = macaroon) do
    copy = discharge_macaroon
    key = Util.Crypto.truncate_or_pad_string(<<0>>, :enacl.secretbox_KEYBYTES())
    new_sig = Util.Crypto.hmac_concat(key, macaroon.signature, discharge_macaroon.signature)
    %Types.Macaroon{copy | signature: new_sig}
  end

  @doc """
  Serializes a Macaroon into a more transmittable format

  2nd argument for "type" can be `:binary` or `:json`
  """
  @spec serialize(Macaroon.Types.Macaroon.t(), :binary | :json) ::
          nil
          | {:error,
             %{
               :__exception__ => any,
               :__struct__ => Jason.EncodeError | Protocol.UndefinedError,
               optional(atom) => any
             }}
          | {:ok, binary}
  def serialize(%Types.Macaroon{} = macaroon, :json) do
    case JSON.encode(macaroon) do
      {:ok, _} = serialized -> serialized
      {:error, details} -> {:error, details}
    end
  end

  def serialize(%Types.Macaroon{} = macaroon, :binary) do
    Binary.encode(macaroon, :v1)
  end

  @doc """
  Deserializes a JSON or Base64 serialized Macaroon string

  2nd argument for "type" can be `:binary` or `:json`

  Returns a `Macaroon.Types.Macaroon` struct
  """
  @spec deserialize(binary, :binary | :json) :: Macaroon.Types.Macaroon.t()
  def deserialize(macaroon_json, :json) when is_binary(macaroon_json) do
    JSON.decode(macaroon_json)
  end

  def deserialize(macaroon_binary, :binary) when is_binary(macaroon_binary) do
    Binary.decode(macaroon_binary, :v1)
  end
end
