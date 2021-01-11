defmodule BinarySerializerTest do
  use ExUnit.Case

  alias Macaroon.Util.Crypto
  alias Macaroon.Serializers

  @m_location "https://example.com"
  @m_id "1234"
  @m_secret "SECRET_CODE"

  test "Should seralize an empty macaroon into an encoded string" do
    m = Macaroon.create_macaroon(@m_location, @m_id, @m_secret)
    encoded_string = Serializers.Binary.encode(m, :v1)

    # This string constant encoded on http://macaroons.io/
    assert encoded_string == "MDAyMGxvY2F0aW9uIGh0dHA6Ly9leGFtcGxlLmNvbQowMDE0aWRlbnRpZmllciAxMjM0CjAwMmZzaWduYXR1cmUgYa7UTK19vYhcFREA-WNi1962CpM6qOuDLBeL2BqYXj8K"
  end

end
