defmodule Macaroon.Util do
  def truncate_or_pad_string(str, target_len \\ 32) when is_binary(str) do
    cond do
      String.length(str) > target_len ->
        {str, _rest} = String.split_at(str, target_len)
        str
      String.length(str) < target_len ->
        str <> String.duplicate("0", target_len - String.length(str))
      String.length(str) == target_len ->
        str
    end
  end
end
