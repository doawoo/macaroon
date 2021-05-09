defmodule MacaroonVerificationTest do
  use ExUnit.Case

  alias Macaroon.Verification
  alias Macaroon.Types.Verification.VerifyParameters

  @location "http://mybank/"
  @id "we used our secret key"
  @key "this is our super secret key; only we should know it"

  describe "First Party Verification" do
    setup do
      m =
        Macaroon.create_macaroon(@location, @id, @key)
        |> Macaroon.add_first_party_caveat("test = caveat")
        |> Macaroon.add_first_party_caveat("user = 1234")

      {:ok, %{m: m}}
    end

    test "should verify when all exact first-party caveats are met (Verification.satisfy_exact/1..2)",
         context do
      result =
        Verification.satisfy_exact("test = caveat")
        |> Verification.satisfy_exact("user = 1234")
        |> Verification.verify(context.m, @key)

      assert {:ok, _result} = result
    end

    test "should NOT verify when all exact first-party caveats are NOT met (Verification.satisfy_exact/1..2)",
         context do
      result = VerifyParameters.build() |> Verification.verify(context.m, @key)

      assert {:error, _result} = result
    end

    test "should verify when all general first-party caveats are met (Verification.satisfy_general/1..2)",
         context do
      result =
        Verification.satisfy_general(fn predicate ->
          if predicate == "test = caveat" do
            true
          else
            false
          end
        end)
        |> Verification.satisfy_general(fn predicate ->
          if predicate == "user = 1234" do
            true
          else
            false
          end
        end)
        |> Verification.verify(context.m, @key)

      assert {:ok, _result} = result
    end
  end

  describe "Third-Party Verification" do
    setup do
      location = "http://myapp/"
      pub_id = "public_id"
      key = "SUPER_SECRET_KEY"

      tp_location = "http://auth.myapp/"
      tp_pub_id = "third_party_pub_id"
      tp_key = "THIRD_PARTY_KEY"

      account_number = "account = 1234"
      expire_time = "time < 2022-01-01T00:00"

      m =
        Macaroon.create_macaroon(location, pub_id, key)
        |> Macaroon.add_first_party_caveat(account_number)
        |> Macaroon.add_third_party_caveat(tp_location, tp_pub_id, tp_key)

      discharge =
        Macaroon.create_macaroon(tp_location, tp_pub_id, tp_key)
        |> Macaroon.add_first_party_caveat(expire_time)

      protected_dischage = Macaroon.prepare_for_request(discharge, m)

      {:ok, %{m: m, discharge: protected_dischage, key: key, tp_key: tp_key}}
    end

    test "should verify when all exact third-party caveats are met (Verification.satisfy_exact/1..2)",
         context do
      result =
        Verification.satisfy_exact("account = 1234")
        |> Verification.satisfy_exact("time < 2022-01-01T00:00")
        |> Verification.verify(context.m, context.key, [context.discharge])

      assert {:ok, _result} = result
    end

    test "should NOT verify when all exact third-party caveats are NOT met (Verification.satisfy_exact/1..2)",
         context do
      result =
        Verification.satisfy_exact("account = 1234")
        |> Verification.verify(context.m, context.key, [context.discharge])

      assert {:error, _result} = result
    end

    test "should NOT verify when all exact third-party when discharges are missing (Verification.satisfy_exact/1..2)",
         context do
      result =
        Verification.satisfy_exact("account = 1234")
        |> Verification.verify(context.m, context.key, [])

      assert {:error, _result} = result
    end
  end
end
