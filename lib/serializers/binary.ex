defmodule Macaroon.Serializers.Binary do
  @moduledoc """
  Module used to encode/decode a Macaroon as a binary, and encode it into Base64 (URL Safe, no padding)
  """
  alias Macaroon.Types

  @packet_prefix_len 4

  @newline_and_space_len 2

  @max_packet_size 65535

  @spec encode(Macaroon.Types.Macaroon.t(), :v1) :: binary | {:error, any}
  def encode(%Types.Macaroon{} = macaroon, :v1) do
    with {:ok, location} <- create_packet_v1("location", macaroon.location),
         {:ok, id} <- create_packet_v1("identifier", macaroon.public_identifier),
         {:ok, sig} <- create_packet_v1("signature", macaroon.signature),
         {:ok, caveats_encoded} <- encode_caveats_v1(macaroon) do
      encoded_string =
        (location <> id <> caveats_encoded <> sig)
        |> Base.url_encode64(padding: false)

      {:ok, encoded_string}
    else
      {:error, _} = err -> err
    end
  end

  @spec decode(binary, :v1) :: Macaroon.Types.Macaroon.t()
  def decode(bin_macaroon, :v1) when is_binary(bin_macaroon) do
    {:ok, decoded} = Base.url_decode64(bin_macaroon, padding: false)
    do_decode_macaroon_v1(decoded)
  end

  # Encoder v1 functions

  defp encode_caveats_v1(%Types.Macaroon{} = macaroon) do
    cavs = macaroon.caveats

    result =
      Enum.reduce_while(cavs, <<>>, fn caveat, packet ->
        IO.inspect(caveat)
        encoded =
          case caveat.party do
            :first -> encode_first_party_caveat_v1(caveat)
            :third -> encode_third_party_caveat_v1(caveat)
          end

        with {:ok, c_encoded} <- encoded do
          {:cont, packet <> c_encoded}
        else
          {:error, _} = err -> {:halt, err}
        end
      end)

    if !match?({:error, _}, result) do
      {:ok, result}
    else
      result
    end
  end

  def create_packet_v1(key, data) when is_binary(key) and is_binary(data) do
    p_size = @packet_prefix_len + @newline_and_space_len + byte_size(key) + byte_size(data)

    if p_size > @max_packet_size do
      {:error, "Packet size is too large for key #{key} and provided data"}
    else
      packet_header =
        Integer.to_string(p_size, 16)
        |> String.pad_leading(4, ["0"])
        |> String.downcase()

      packet_data = <<>> <> key <> " " <> data <> "\n"
      {:ok, packet_header <> packet_data}
    end
  end

  defp encode_first_party_caveat_v1(%Types.Caveat{} = c) do
    create_packet_v1("cid", c.caveat_id)
  end

  defp encode_third_party_caveat_v1(%Types.Caveat{} = c) do
    with {:ok, cid} <- create_packet_v1("cid", c.caveat_id),
         {:ok, vid} <- create_packet_v1("vid", c.verification_key_id),
         {:ok, location} <- create_packet_v1("cl", c.location) do
      {:ok, cid <> vid <> location}
    else
      {:error, _} = err -> err
    end
  end

  # Decoder v1 functions

  defp do_decode_macaroon_v1(decoded_bin) when is_binary(decoded_bin) do
    packets = do_decode_packets_v1(decoded_bin, [])
    base_mac = Types.Macaroon.build()
    mac = do_parse_packets_v1(packets, base_mac)
    %Types.Macaroon{mac | caveats: Enum.reverse(mac.caveats)}
  end

  defp build_third_party_caveat(location, vid, id) do
    location = String.replace(location, "cl ", "") |> String.trim_trailing()
    verification_id = String.replace(vid, "vid ", "") |> String.trim_trailing()
    caveat_id = String.replace(id, "cid ", "") |> String.trim_trailing()

    %Types.Caveat{
      party: :third,
      caveat_id: caveat_id,
      location: location,
      verification_key_id: verification_id
    }
  end

  defp do_parse_packets_v1(packets, %Types.Macaroon{} = macaroon) when length(packets) > 0 do
    [pkt | rest] = packets

    {macaroon, rest} =
      case pkt do
        "location " <> location ->
          {%Types.Macaroon{macaroon | location: location |> String.trim_trailing()}, rest}

        "identifier " <> id ->
          {%Types.Macaroon{macaroon | public_identifier: id |> String.trim_trailing()}, rest}

        "signature " <> sig ->
          {%Types.Macaroon{macaroon | signature: sig |> String.trim_trailing()}, rest}

        "cl " <> caveat_location ->
          [vid, id | new_rest] = rest
          c = build_third_party_caveat(caveat_location, vid, id)

          {%Types.Macaroon{macaroon | caveats: macaroon.caveats ++ [c]},
           new_rest}

        "cid " <> caveat_id ->
          c = Types.Caveat.build(caveat_id: caveat_id |> String.trim_trailing())

          {%Types.Macaroon{macaroon | caveats: macaroon.caveats ++ [c]},
           rest}
      end

    do_parse_packets_v1(rest, macaroon)
  end

  defp do_parse_packets_v1(_packets, macaroon), do: macaroon

  defp do_decode_packets_v1(bin, pkt_acc) when is_binary(bin) do
    len = binary_part(bin, 0, @packet_prefix_len)
    {len, _rest} = Integer.parse(len, 16)
    pkt = binary_part(bin, @packet_prefix_len, len - @packet_prefix_len)
    rest = binary_part(bin, len, byte_size(bin) - byte_size(pkt) - @packet_prefix_len)

    pkt_acc = [pkt | pkt_acc]

    if String.length(rest) > 0 do
      do_decode_packets_v1(rest, pkt_acc)
    else
      pkt_acc
    end
  end
end
