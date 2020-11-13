defmodule Macaroon.Util.Crypto do
  @key_gen_string "macaroons-key-generator"

  @spec create_derived_key(binary) :: binary
  def create_derived_key(key) when is_binary(key) do
    :crypto.hmac(:sha256, @key_gen_string, key)
  end

  @spec hmac_concat(binary, binary, binary) :: binary
  def hmac_concat(key, dataA, dataB) when is_binary(key) and is_binary(dataA) and is_binary(dataB) do
    hash_a = :crypto.hmac(:sha256, key, dataA)
    hash_b = :crypto.hmac(:sha256, key, dataB)
    :crypto.hmac(:sha256, key, hash_a <> hash_b)
  end

  @spec truncate_or_pad_string(binary, number) :: binary
  def truncate_or_pad_string(str, target_len \\ 32) when is_binary(str) do
    cond do
      byte_size(str) > target_len ->
        {str, _rest} = String.split_at(str, target_len)
        str
      byte_size(str) < target_len ->
        str <> String.duplicate(<<0>>, target_len - byte_size(str))
      byte_size(str) == target_len ->
        str
    end
  end
end
