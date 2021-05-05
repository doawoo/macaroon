defmodule CryptoUtilTest do
  use ExUnit.Case

  alias Macaroon.Util.Crypto

  @target_bin_size 32

  test "Truncate or pad binaries to a target byte length (Crypto.truncate_or_pad_string/2)" do
    bin = Crypto.truncate_or_pad_string(<<0>>, @target_bin_size)
    assert byte_size(bin) == @target_bin_size

    bin = Crypto.truncate_or_pad_string(<<0>>)
    assert byte_size(bin) == @target_bin_size

    bin = Crypto.truncate_or_pad_string(bin <> bin, @target_bin_size)
    assert byte_size(bin) == @target_bin_size

    bin = Crypto.truncate_or_pad_string(bin, @target_bin_size)
    assert byte_size(bin) == @target_bin_size
  end

  test "Concats two HMAC digests and digests them with the same key" do
    digest =
      Crypto.hmac_concat("!!key555222%", "dataA", "dataB")
      |> Base.encode16()
      |> String.downcase()

    assert digest == "b3b39ea50dc6272aac1001dfd8cf161a82807d4901c3bb2ed65ce272919d450a"
  end
end
