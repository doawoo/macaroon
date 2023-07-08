defmodule MacaroonV2 do
  import Bitwise
  @field_types %{location: 1, identifier: 2, vid: 4, signature: 6}

  def encode_field_type(field_type) do
    encode_varuint64(field_type)
  end

  def encode_field_length(length) do
    encode_varuint64(length)
  end

  def encode_varuint64(num) do
    encode_varuint64(num, <<>>)
  end

  defp encode_varuint64(0x80, enc), do: enc

  defp encode_varuint64(num, encoded) when num > 0x80 do
    new_encoded = encoded <> (num |> band(0xFF) |> bor(0x80))
    new_num = num >>> 7
    encode_varuint64(new_num, new_encoded)
  end

  defp encode_varuint64(num, _) do
    <<num>>
  end

  def encode_field_content(content) do
    content
  end

  def encode_macaroon(version, location, identifier, caveats, signature) do
    version_bytes = <<version::size(8)>>
    location_bytes = encode_field(@field_types.location, location)
    identifier_bytes = encode_field(@field_types.identifier, identifier)
    caveats_bytes = encode_caveats(caveats)
    signature_bytes = encode_field(@field_types.signature, signature)

    version_bytes <>
      location_bytes <> identifier_bytes <> <<0>> <> caveats_bytes <> <<0>> <> signature_bytes
  end

  def encode_caveats(caveats) do
    Enum.map(caveats, &encode_caveat/1)
    |> List.flatten()
    |> Enum.join()
  end

  def encode_caveat([]), do: [<<>>]

  def encode_caveat(caveat) do
    location_bytes = encode_field(@field_types.location, caveat.location)
    identifier_bytes = encode_field(@field_types.identifier, caveat.identifier)
    vid_bytes = encode_optional_field(@field_types.vid, caveat.vid)

    location_bytes <> identifier_bytes <> vid_bytes
  end

  def encode_field(field_type, field_content) do
    encoded_field_type = encode_field_type(field_type)
    encoded_field_length = encode_field_length(byte_size(field_content))
    encoded_field_content = encode_field_content(field_content)

    encoded_field_type <> encoded_field_length <> encoded_field_content
  end

  def encode_optional_field(_, nil), do: <<>>

  def encode_optional_field(field_type, field_content) do
    encode_field(field_type, field_content)
  end
end
