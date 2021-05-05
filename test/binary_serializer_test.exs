defmodule BinarySerializerTest do
  use ExUnit.Case

  alias Macaroon.Serializers
  alias Macaroon.Util.Crypto

  @m_location "https://example.com"
  @m_id "1234"
  @m_secret "SECRET_CODE"

  describe "BinarySerializer" do
    test "Should seralize an empty macaroon into an encoded string" do
      m = Macaroon.create_macaroon(@m_location, @m_id, @m_secret)
      encoded_string = Serializers.Binary.encode(m, :v1)

      decoded = Serializers.Binary.decode(encoded_string, :v1)
      assert m == decoded
    end

    test "Should seralize a first party caveat" do
      m = Macaroon.create_macaroon(@m_location, @m_id, @m_secret)
      |> Macaroon.add_first_party_caveat("account = 1234")

      encoded_string = Serializers.Binary.encode(m, :v1)

      decoded = Serializers.Binary.decode(encoded_string, :v1)
      assert m == decoded
    end

    test "Should seralize a third party caveat" do
      static_nonce = Crypto.truncate_or_pad_string(<<0>>, :enacl.secretbox_NONCEBYTES)

      m = Macaroon.create_macaroon(@m_location, @m_id, @m_secret)
      |> Macaroon.add_third_party_caveat("http://auth.example.com", "account = 1234", "SECRET_KEY_TP", static_nonce)

      encoded_string = Serializers.Binary.encode(m, :v1)

      decoded = Serializers.Binary.decode(encoded_string, :v1)
      assert m == decoded
    end

    test "Should fail to serialize a first party packet that is too long" do
      m = Macaroon.create_macaroon(@m_location, @m_id, @m_secret)
      |> Macaroon.add_first_party_caveat(String.pad_leading("a = ", 70000, "b"))

      encoded_string = Serializers.Binary.encode(m, :v1)

      assert {:error, _} = encoded_string
    end

    test "Should fail to serialize a third party packet that is too long" do
      m = Macaroon.create_macaroon(@m_location, @m_id, @m_secret)
      |> Macaroon.add_third_party_caveat(String.pad_leading("a = ", 70000, "b"), "id", "key")

      encoded_string = Serializers.Binary.encode(m, :v1)

      assert {:error, _} = encoded_string
    end
  end
end
