defmodule BinarySerializerTest do
  use ExUnit.Case

  alias Macaroon.Serializers

  @m_location "https://example.com"
  @m_id "1234"
  @m_secret "SECRET_CODE"

  test "Should seralize an empty macaroon into an encoded string" do
    m = Macaroon.create_macaroon(@m_location, @m_id, @m_secret)
    encoded_string = Serializers.Binary.encode(m, :v1)

    # This string constant encoded on http://macaroons.io/
    assert encoded_string == "MDAyMWxvY2F0aW9uIGh0dHBzOi8vZXhhbXBsZS5jb20KMDAxNGlkZW50aWZpZXIgMTIzNAowMDJmc2lnbmF0dXJlIGGu1Eytfb2IXBURAPljYtfetgqTOqjrgywXi9gamF4_Cg"
  end

end
