defmodule MacaroonTest do
  use ExUnit.Case

  alias Macaroon.Util.Crypto

  @m_location "https://location"
  @m_id "my_public_ID"
  @m_secret "SuPeR_SecReT_5!"

  @t_location "https://another.location"
  @t_id "third_party_ID"
  @t_secret "Third_SuPeR_SecReT_5!"

  test "Create an empty macaroon with a valid signature (Macaroon.create_macaroon/3)" do
    m = Macaroon.create_macaroon(@m_location, @m_id, @m_secret)

    sig =
      m.signature
      |> Base.encode16()
      |> String.downcase()

    assert sig == "6690ae24ac0e84dcff4f67fb3e24034c77812930d40a175edacd9620fd8cba1e"
  end

  test "Add a first party caveat to a macaroon (Macaroon.add_first_party_caveat/1)" do
    m =
      Macaroon.create_macaroon(@m_location, @m_id, @m_secret)
      |> Macaroon.add_first_party_caveat("foo=bar")

    sig =
      m.signature
      |> Base.encode16()
      |> String.downcase()

    assert sig == "65f8017ea1c5ec2fb2005017b13c461a67451b69df208b05f68287a2171a94c0"
  end

  test "Add a third party caveat to a macaroon (Macaroon.add_third_caveat/5)" do
    # use a static nonce because we want to compare signatures
    static_nonce = Crypto.truncate_or_pad_string(<<0>>, :enacl.secretbox_NONCEBYTES())

    m =
      Macaroon.create_macaroon(@m_location, @m_id, @m_secret)
      |> Macaroon.add_third_party_caveat(@t_location, @t_id, @t_secret, static_nonce)

    sig =
      m.signature
      |> Base.encode16()
      |> String.downcase()

    c =
      m.third_party_caveats
      |> List.first()

    vid =
      c.verification_key_id
      |> Base.encode16()
      |> String.downcase()

    assert vid ==
             "00000000000000000000000000000000000000000000000015c6c99d220519b26a16d216eca12d5bccc996ab92dc199ef0e7d30c429aea6b2266eef690fa081f0e5e9124ff31f3cc"

    assert sig == "41d375c89354ff29c98860e25e350974b024ab14f73f36f59a8110bcb4429ba1"
  end

  test "Two macaroons with the same third party caveat should use different nonces (Macaroon.add_third_caveat/5)" do
    m1 =
      Macaroon.create_macaroon(@m_location, @m_id, @m_secret)
      |> Macaroon.add_third_party_caveat(@t_location, @t_id, @t_secret)

    sigA =
      m1.signature
      |> Base.encode16()
      |> String.downcase()

    m2 =
      Macaroon.create_macaroon(@m_location, @m_id, @m_secret)
      |> Macaroon.add_third_party_caveat(@t_location, @t_id, @t_secret)

    sigB =
      m2.signature
      |> Base.encode16()
      |> String.downcase()

    assert sigA != sigB
  end

  test "Should prepare a macaroon for request sending (Macaroon.prepare_for_request/2)" do
    # use a static nonce because we want to compare signatures
    static_nonce = Crypto.truncate_or_pad_string(<<0>>, :enacl.secretbox_NONCEBYTES())

    caveat_location = "http://auth.myCoolApp"
    caveat_key = "KEY_SECRET_THIRD_PARTY"
    caveat_id = "third_party_id"

    m =
      Macaroon.create_macaroon(
        "http://myCoolApp",
        "first_party_id",
        "KEY_SUPER_SECRET_FIRST_PARTY"
      )
      |> Macaroon.add_first_party_caveat("whoiam = user123")
      |> Macaroon.add_third_party_caveat(caveat_location, caveat_id, caveat_key, static_nonce)

    discharge =
      Macaroon.create_macaroon(caveat_location, caveat_id, caveat_key)
      |> Macaroon.add_first_party_caveat("i_am_admin = true")

    protected_m = Macaroon.prepare_for_request(discharge, m)

    protected_sig =
      protected_m.signature
      |> Base.encode16()
      |> String.downcase()

    assert protected_sig == "f297c1ec5db0072e1605dcc50d0becdb156765e9447be7a61036564e923b3357"
  end
end
