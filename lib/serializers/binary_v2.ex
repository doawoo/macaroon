defmodule Macaroon.Serializers.Binary.V2 do
  @moduledoc """
  Version 2 Macaroon binary encoding and decoding.
  See format [doc](https://github.com/rescrv/libmacaroons/blob/master/doc/format.txt) for spec.
  """

  import Bitwise
  alias Macaroon.Types.{Macaroon, Caveat}

  @field_types %{location: 1, public_identifier: 2, vid: 4, signature: 6, eos: 0}

  def encode(%Macaroon{
        public_identifier: identifier,
        location: location,
        signature: signature,
        caveats: caveats
      }) do
    encode_macaroon(2, location, identifier, caveats, signature)
  end

  def encode_macaroon(version, location, identifier, caveats, signature) do
      with {:ok, location} <- encode_field(@field_types.location, location),
         {:ok, id} <- encode_field(@field_types.public_identifier, identifier),
         {:ok, sig} <- encode_field(@field_types.signature, signature),
         {:ok, caveats_encoded} <- encode_caveats(caveats) do

      version = <<version::size(8)>>
      encoded_string =
        (version <> location <> id <> <<@field_types.eos>> <> caveats_encoded <> <<@field_types.eos>> <> sig)
        |> Base.url_encode64(padding: false)

      {:ok, encoded_string}
    else
      {:error, _} = err -> err
    end
  end

  def encode_field(field_type, field_content) when is_binary(field_content) do
    encode_packet(field_type, byte_size(field_content), field_content)
  end

  def encode_packet(field_type, len, field_content) do
    encoded_field_type = encode_varuint64(field_type)
    encoded_field_length = encode_varuint64(len)

    {:ok, encoded_field_type <> encoded_field_length <> field_content}
  end

  def encode_varuint64(num) when num < 0,
    do: {:error, "Integer must be positive, got #{Integer.to_string(num)}"}

  def encode_varuint64(num) when is_integer(num) and num < 0x80, do: <<num>>
  def encode_varuint64(num) when num >= 0x80, do: encode_varuint64(<<>>, num)

  def encode_varuint64(data, num) do
    new_encoded = num |> band(0x7F)
    new_num = num >>> 7

    if new_num == 0 do
      data <> <<new_encoded>>
    else
      new_data = data <> <<bor(new_encoded, 0x80)>>
      encode_varuint64(new_data, new_num)
    end
  end

  def encode_caveats(caveats) do
    encoded = caveats
    |> Enum.map(&encode_caveat/1)
    |> List.flatten()
    |> Enum.join()

    {:ok, encoded}
  end

  def encode_caveat([]), do: [<<>>]

  def encode_caveat(%Caveat{} = caveat) do
    {:ok, location_bytes} = encode_optional_location(caveat)
    {:ok, identifier_bytes} = encode_field(@field_types.public_identifier, caveat.caveat_id)
    {:ok, vid_bytes} = encode_optional_vid(caveat)

    location_bytes <> identifier_bytes <> vid_bytes <> <<@field_types.eos>>
  end

  def encode_caveat(_caveat) do
    {:error, "Caveat must be of type Caveat."}
  end

  defp encode_optional_location(%{location: location}) when not is_nil(location),
    do: encode_field(@field_types.location, location)

  defp encode_optional_location(_), do: {:ok, <<>>}
  defp encode_optional_vid(%{vid: vid}), do: encode_field(@field_types.vid, vid)
  defp encode_optional_vid(_), do: {:ok, <<>>}

  @doc """
  Decode a Base64 encoded macaroon.
  """
  def decode_mac(binary) do
    {:ok, decoded} = Base.url_decode64(binary, padding: false)
    # first we pick off the version
    <<v::size(8), rest::binary>> = decoded
    # then decode the rest
    decode_fields(rest, %{version: v})
  end

  @doc """
  Decode fields of binary macaroon.
  Fields are recursively accumulated:
  - if the accumulator is empty, return the decoded macaroon.
  - Field Type EOS (a zero byte) delimits the caveats section, and individual caveats within that section.
  """
  def decode_fields(<<>>, mac), do: {:ok, mac}

  def decode_fields(<<0::size(8), rest::binary>>, %{caveats: caveats} = mac) do
    case Enum.count(caveats) > 0 do
      true ->
        decode_fields(rest, mac)

      false ->
        decode_fields(rest, mac)
    end
  end

  ## Decoding

  def decode_fields(<<0::size(8), rest::binary>>, mac) do
    <<first::size(8), data::binary>> = rest

    # If there is a second zero byte, this means the caveats section is empty.
    # Proceed to decoding the rest of the fields.
    # Else, decode the caveats.
    if first == 0 do
      decode_fields(data, mac)
    else
      new_mac = Map.put(mac, :caveats, [])
      decode_caveats(rest, new_mac, %{})
    end
  end

  def decode_fields(data, mac) do
    with {:ok, {field_name, val}, rest} <- decode_packet(data) do
      mac = Map.put(mac, field_name, val)
      decode_fields(rest, mac)
    else
      err -> err
    end
  end

  def decode_packet(data) when is_binary(data) do
    with <<field_type::size(8), lv::binary>> <- data,
         {:ok, field_name} <- get_field_name(field_type) do
      {:ok, len, bytes_read} = decode_len(lv)
      {:ok, val, rest} = decode_value(lv, bytes_read, bytes_read + len)
      {:ok, {field_name, val}, rest}
    end
  end

  @doc """
  Caveats are recursively accumulated, until a single zero byte denotes the end of caveats.
  """
  def decode_caveats(<<0::size(8), rest::binary>>, %{caveats: _} = mac, _acc) do
    decode_fields(rest, mac)
  end

  def decode_caveats(bin, %{caveats: _} = mac, acc) do
    with {:ok, {field_name, val}, rest} <- decode_packet(bin) do
      new_acc = Map.put(acc, field_name, val)

      # if the next byte is zero, the caveat section is ended.
      # we add it and process the next caveat.
      # if its not zero, there is more to decode for this section
      case first_byte_zero?(rest) do
        true ->
          new_mac = add_caveat_section(mac, new_acc)

          rest
          |> binary_slice(1..-1//1)
          |> decode_caveats(new_mac, %{})

        false ->
          decode_caveats(rest, mac, new_acc)
      end
    end
  end

  def add_caveat_section(%{caveats: caveats} = mac, section) do
    Map.put(mac, :caveats, caveats ++ [section])
  end

  def decode_len(<<len::size(8), _rest::binary>> = lv) do
    if len < 0x80 do
      {:ok, len, 1}
    else
      decode_varuint64(lv)
    end
  end

  @doc """
  Read a value from a binary based on index.
  Return the rest of the binary.
  """
  def decode_value(data, read_start, read_end) do
    val = binary_part(data, read_start, read_end - 1)
    # read to the end
    rest = binary_slice(data, read_end..-1//1)
    {:ok, val, rest}
  end

  def decode_varuint64(data) do
    case parse_varint(data, 0, 0) do
      {:ok, val, bytes_read} ->
        bytes_left = binary_slice(data, 0..bytes_read)
        {:ok, val, bytes_left}

      msg ->
        {:error, msg}
    end
  end

  @doc """
  Parses a variable length int.
  Reference Python impl: https://github.com/ecordell/pymacaroons/blob/master/pymacaroons/serializers/binary_serializer.py#L315
  """
  def parse_varint(<<b::size(8), data::binary>>, acc, bytes_read) do
    cond do
      b < 0x80 ->
        # this is the last byte of the varint encoding
        # it can be directly added to the result x by shifting it s bits to the left.
        {:ok, bor(acc, b <<< 7), bytes_read + 1}

      true ->
        # the value of the byte is extracted by performing a bitwise AND operation with 0x7f (127 in decimal),
        # and then shifted 7 bits to the left and ORed with the accumulated result x.
        acc = acc ||| band(b, 0x7F) <<< 7
        parse_varint(data, acc, bytes_read + 1)
    end
  end

  defp get_field_name(int) do
    if int in Map.values(@field_types) do
      [{field_name, _}] = Enum.filter(@field_types, fn {_k, v} -> v == int end)
      {:ok, field_name}
    else
      {:ok, Integer.to_string(int)}
    end
  end

  defp first_byte_zero?(<<0::size(8), _::binary>>), do: true
  defp first_byte_zero?(_), do: false
end
