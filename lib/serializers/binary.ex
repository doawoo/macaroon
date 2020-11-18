defmodule Macaroon.Serializers.Binary do
  alias Macaroon.Types

  @packet_prefix_len 4

  @packet_location 1
  @packet_id 2
  @packet_vid 4
  @packer_sig 6
  @eos 0

  @newline_and_space_len 2

  @max_packet_size 65535

  @spec encode(Macaroon.Types.Macaroon.t(), :v1) :: binary | {:error, any}
  def encode(%Types.Macaroon{} = macaroon, :v1) do
    with {:ok, location} <- create_packet_v1("location", macaroon.location),
      {:ok, id} <- create_packet_v1("identifier", macaroon.public_identifier),
      {:ok, sig} <- create_packet_v1("signature", macaroon.signature),
      {:ok, caveats_encoded} <- encode_caveats_v1(macaroon) do
        location <> id <> caveats_encoded <> sig
        |> Base.encode64()
        |> String.trim_trailing("=")
      else
        {:error, _} = err -> err
      end
  end

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
end
