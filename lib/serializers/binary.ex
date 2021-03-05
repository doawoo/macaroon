defmodule Macaroon.Serializers.Binary do
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
        location <> id <> caveats_encoded <> sig
        |> Base.encode64(padding: false)
        |> String.replace("/", "_")
      else
        {:error, _} = err -> err
      end
  end

  def decode(bin_macaroon, :v1) when is_binary(bin_macaroon) do
    {:ok, decoded} = Base.url_decode64(bin_macaroon, padding: false)
    decode_packets_v1(decoded)
  end

  # Encoder v1 functions

  defp encode_caveats_v1(%Types.Macaroon{} = macaroon) do
    cavs = macaroon.first_party_caveats ++ macaroon.third_party_caveats
    result = Enum.reduce_while(cavs, <<>>, fn caveat, packet ->
       encoded = case caveat.party do
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

  defp create_packet_v1(key, data) when is_binary(key) and is_binary(data) do
    p_size = @packet_prefix_len + @newline_and_space_len + byte_size(key) + byte_size(data)
    if p_size > @max_packet_size do
      {:error, "Packet size is too large for key #{key} and provided data"}
    else
      packet_header = Integer.to_string(p_size, 16)
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
      cid <> vid <> location
    else
      {:error, _} = err -> err
    end
  end

  # Decoder v1 functions

  defp decode_packets_v1(decoded_bin) when is_binary(decoded_bin) do
    packets = do_decode_packet_v1(decoded_bin, [])
    base_mac = Types.Macaroon.build()
    Enum.reduce(packets, base_mac, fn pkt, m ->
      case String.split(pkt, " ", parts: 2) do
        ["location", location] ->
          %Types.Macaroon{m | location: location}
        ["identifier", id] ->
          %Types.Macaroon{m | public_identifier: id}
        ["signature", sig] ->
          %Types.Macaroon{m | signature: sig}
        _ -> m
      end
    end)
  end

  defp do_decode_packet_v1(bin, pkt_acc) when is_binary(bin) do
    {len, rest} = String.split_at(bin, @packet_prefix_len)
    {len, _rest} = Integer.parse(len, 16)
    {pkt, rest} = String.split_at(rest, len - 4)

    pkt_acc = [pkt | pkt_acc]

    if String.length(rest) > 0 do
      do_decode_packet_v1(rest, pkt_acc)
    else
      pkt_acc
    end
  end
end
