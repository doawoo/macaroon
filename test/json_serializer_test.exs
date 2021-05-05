defmodule JsonSerializerTest do
  use ExUnit.Case

  alias Macaroon.Util.Crypto
  alias Macaroon.Serializers

  @m_location "https://location"
  @m_id "my_public_ID"
  @m_secret "SuPeR_SecReT_5!"

  @t_location "https://another.location"
  @t_id "third_party_ID"
  @t_secret "Third_SuPeR_SecReT_5!"

  test "Should seralize an empty macaroon into a JSON string" do
    m = Macaroon.create_macaroon(@m_location, @m_id, @m_secret)

    sig =
      m.signature
      |> Base.encode16()
      |> String.downcase()

    {:ok, json_string} = Serializers.JSON.encode(m)
    obj = Jason.decode!(json_string)

    assert obj["signature"] == sig
    assert obj["location"] == @m_location
    assert obj["identifier"] == @m_id
  end

  test "Should encode a first party caveat" do
    pred = "foo=bar"

    m =
      Macaroon.create_macaroon(@m_location, @m_id, @m_secret)
      |> Macaroon.add_first_party_caveat(pred)

    sig =
      m.signature
      |> Base.encode16()
      |> String.downcase()

    {:ok, json_string} = Serializers.JSON.encode(m)
    obj = Jason.decode!(json_string)

    assert obj["signature"] == sig

    assert obj["caveats"] == [
             %{
               "cl" => nil,
               "cid" => pred,
               "vid" => nil
             }
           ]
  end

  test "Should encode a third party caveat" do
    static_nonce = Crypto.truncate_or_pad_string(<<0>>, :enacl.secretbox_NONCEBYTES())

    m =
      Macaroon.create_macaroon(@m_location, @m_id, @m_secret)
      |> Macaroon.add_third_party_caveat(@t_location, @t_id, @t_secret, static_nonce)

    sig =
      m.signature
      |> Base.encode16()
      |> String.downcase()

    {:ok, json_string} = Serializers.JSON.encode(m)
    obj = Jason.decode!(json_string)

    c = m.third_party_caveats |> List.first()

    vid_check =
      c.verification_key_id
      |> Base.encode16()
      |> String.downcase()

    assert obj["signature"] == sig

    assert obj["caveats"] == [
             %{
               "cl" => @t_location,
               "cid" => @t_id,
               "vid" => vid_check
             }
           ]
  end

  test "Should decode a macaroon" do
    static_nonce = Crypto.truncate_or_pad_string(<<0>>, :enacl.secretbox_NONCEBYTES())

    fp_pred = "foo=bar"

    m =
      Macaroon.create_macaroon(@m_location, @m_id, @m_secret)
      |> Macaroon.add_first_party_caveat(fp_pred)
      |> Macaroon.add_third_party_caveat(@t_location, @t_id, @t_secret, static_nonce)

    {:ok, json_string} = Serializers.JSON.encode(m)

    decoded_macaroon = Macaroon.Serializers.JSON.decode(json_string)

    assert decoded_macaroon == m
  end
end
