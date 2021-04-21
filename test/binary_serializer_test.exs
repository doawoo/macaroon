defmodule BinarySerializerTest do
  use ExUnit.Case

  alias Macaroon.Serializers

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

    test "Should seralize a third party caveat" do
      m = Macaroon.create_macaroon(@m_location, @m_id, @m_secret)
      |> Macaroon.add_first_party_caveat("account = 1234")
      |> Macaroon.add_third_party_caveat("location", "id", "key")

      encoded_string = Serializers.Binary.encode(m, :v1)

      decoded = Serializers.Binary.decode(encoded_string, :v1)
      assert m == decoded
    end
  end
end
