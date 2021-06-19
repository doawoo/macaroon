defmodule RSACaveatTest do
  use ExUnit.Case

  alias Macaroon.Util.CaveatHelpers

  @predicate "HELLO_WORLD"
  @set_nonce_length 64

  # It Should be noted, these keys SHOULD NOT BE USED OUTSIDE OF THIS UNIT TEST :D

  @public_key """
  -----BEGIN PUBLIC KEY-----
  MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2VvPvhHpiDXjv7Qvy3W5
  /DbqZ5M7iCL0+Xs1tu5vjxV8QU0rgMSJhRtFI2YRitKe07OgXHTXlnhTiDep7XWm
  6jqWhzbWN9F9s5ChKHbkPOr602x4CUnjjo1UG9PIqyYjVVdQXbuEkdXuvsWEFlwI
  l8IJy+ahaX6hCx1AmOvk1j8J78EwkJJaDDV+TAwELVM6VwrPABQU6drpdOwiaozi
  P1RaKJsE/ZPc7J2BX6xGZMLP7Ez4Gqf3CZceawNDYhiQDnNE2s5AcfDlPeKvqBtJ
  7ITrN37bZnr3Kna8TwE20FDTDKtVQz5pifSNLniqcyx00eIbvbbezpQMMQAQXdYB
  twIDAQAB
  -----END PUBLIC KEY-----
  """

  @private_key """
  -----BEGIN RSA PRIVATE KEY-----
  MIIEpAIBAAKCAQEA2VvPvhHpiDXjv7Qvy3W5/DbqZ5M7iCL0+Xs1tu5vjxV8QU0r
  gMSJhRtFI2YRitKe07OgXHTXlnhTiDep7XWm6jqWhzbWN9F9s5ChKHbkPOr602x4
  CUnjjo1UG9PIqyYjVVdQXbuEkdXuvsWEFlwIl8IJy+ahaX6hCx1AmOvk1j8J78Ew
  kJJaDDV+TAwELVM6VwrPABQU6drpdOwiaoziP1RaKJsE/ZPc7J2BX6xGZMLP7Ez4
  Gqf3CZceawNDYhiQDnNE2s5AcfDlPeKvqBtJ7ITrN37bZnr3Kna8TwE20FDTDKtV
  Qz5pifSNLniqcyx00eIbvbbezpQMMQAQXdYBtwIDAQABAoIBAQCQ2E77EYK3g3nu
  8Ut8YUp8WbghJ4tfcDQh4MptyjzLc/zmo19fIxmlewO60DTWdv7iguxVUIOuQSch
  Oj7iACooIrzXBGMCtXb352SNy5TTR5+4rqrbPcMH5wRqutoZu4OGRnZG0ERKzu6X
  cJZSNCiBwQu4NkvQOlNlTawTe/d2ETdqQ66wmZy6iJxIT2z1O73mlH6P2pECPyYC
  1inwtsi8GmwxONzzZ+qJbmP+7O7sIyX1MHpK1KdcN6IRBIGrO2NLhKjLvmEjAUGS
  EnYcPKNnANRtlzxK1ApZKh50hVjcI6bO6PTVCmmOT+Q+pOmavVPonQgv/+LHp1pi
  OLapsCmpAoGBAPgWSFdyPd6/8xuBF1aaC8pRabrE/RI1cEGgjDmp1g8UNhHEu6EM
  ldfcjGd/40uqVY5gZHUcsfOxSq78Ub/my6chKslKeFq3mjA80BcL2gYR/mcTORJo
  Yh877i/mZ5nBXqzHvq3SAzS5cyhhQn6c9w4D/pZltB2OUXgXyGQG2SIlAoGBAOBK
  nuogqsU8scQZJbW/ovrMAwWoDxkXg62IfMqTxhYTNpJ2ErD+EJKRsaDZyHbnLMg6
  1/eOkJAOjs/gs3SnKF1aedq0FFWe2EWNixbPRWxTQKpDlogGxr4rDxzomSjwskA7
  xQ86+rk+oJ8y8/ecUwLlopFrNqHztfR8VUmUKXerAoGABMUI5wV/QwUVu3Wj6TpU
  97LRAZI/+1Wjrt9TUth9ERUmZPkPUm1XhCrtWCARUqcXtgEMbWP719+UvACF4dai
  G7h7hhs0bSoSgNLqfUbxDiTSa1DnS/9Nw6P3VFxtqXsaQuAkPltHTIA0QpZ8HMsP
  xOk2v9V8vQS7dD+gzquDCTECgYAImpQyAwLKAiQHk7dgm3NTD5RmGSZLHh3NAFlZ
  JAYLPr1vLNxWschM9w3LT89i0Edlfuxd8LgW7pgH3WTE6syfmCLogtPs3OUK9f0J
  6PWOzDrEzUbu/OOO0/QGdd26NlGAKUrL5MVNadubf8bgDr0YdVqhHW3BFKo8MLDM
  28QjdQKBgQCW34ED6X5Jycsp045ag/LHmfZGtPUeOFuHXMwXcTmXXnexrd/vkGZO
  DcpjN6U58dzGeozvNHP02OKx6MbJMMRRH5GAnGXTFFmc55wWSPPTqBeY7SV9rt/h
  osJnbycICfAwoMN0ybru99G1ACeTHuMWK9IDE59p3otN7eaQreGz+w==
  -----END RSA PRIVATE KEY-----
  """

  test "Should properly encrypt a third-party caveat with a given key pair and a set nonce length" do
    [pem_entry | _] = :public_key.pem_decode(@private_key)
    priv_key = :public_key.pem_entry_decode(pem_entry)

    [pem_entry | _] = :public_key.pem_decode(@public_key)
    pub_key = :public_key.pem_entry_decode(pem_entry)

    m =
      Macaroon.create_macaroon("unit_tests", "public_id", "secret")
      |> CaveatHelpers.add_rsa_third_party_caveat(
        "tp_location",
        @predicate,
        pub_key,
        @set_nonce_length
      )

    c = m.caveats |> List.first()

    {key, predicate} =
      CaveatHelpers.decrypt_rsa_third_party_caveat(c, priv_key, @set_nonce_length)

    assert predicate == @predicate
    assert byte_size(key) == @set_nonce_length
  end

  test "Should properly encrypt a third-party caveat with a given key pair and a default nonce length" do
    [pem_entry | _] = :public_key.pem_decode(@private_key)
    priv_key = :public_key.pem_entry_decode(pem_entry)

    [pem_entry | _] = :public_key.pem_decode(@public_key)
    pub_key = :public_key.pem_entry_decode(pem_entry)

    m =
      Macaroon.create_macaroon("unit_tests", "public_id", "secret")
      |> CaveatHelpers.add_rsa_third_party_caveat(
        "tp_location",
        @predicate,
        pub_key
      )

    c = m.caveats |> List.first()

    data = CaveatHelpers.decrypt_rsa_third_party_caveat(c, priv_key)

    assert String.contains?(data, @predicate)
  end
end
