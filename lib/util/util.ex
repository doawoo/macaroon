defmodule Macaroon.Util do
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
