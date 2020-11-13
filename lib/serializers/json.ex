defmodule Macaroon.Serializers.JSON do
  alias Macaroon.Types

  @spec encode(Macaroon.Types.Macaroon.t()) :: binary
  def encode(%Types.Macaroon{} = macaroon) do
    %{
      "location" => macaroon.location,
      "identifier" => macaroon.public_identifier,
      "signature" => macaroon.signature |> Base.encode16() |> String.downcase(),
      "caveats" =>
        Enum.map(macaroon.first_party_caveats, &encode_caveat/1) ++
          Enum.map(macaroon.third_party_caveats, &encode_caveat/1)
    } |> Jason.encode!()
  end

  @spec decode(binary) :: Types.Macaroon.t()
  def decode(string) when is_binary(string) do
    raw_map = Jason.decode!(string)

    location = raw_map["location"]
    identifier = raw_map["identifier"]
    signature = raw_map["signature"]
    |> String.upcase()
    |> Base.decode16!()

    first_party_caveats = Enum.filter(raw_map["caveats"], fn c -> c["vid"] == nil end)
    third_party_caveats = Enum.filter(raw_map["caveats"], fn c -> c["vid"] != nil end)

    Types.Macaroon.build(
      location: location,
      public_identifier: identifier,
      signature: signature,
      first_party_caveats: Enum.map(first_party_caveats, &decode_caveat/1),
      third_party_caveats: Enum.map(third_party_caveats, &decode_caveat/1)
    )
  end

  defp encode_caveat(%Types.Caveat{} = caveat) do
    vid = if caveat.verification_key_id != nil do
      caveat.verification_key_id
      |> Base.encode16()
      |> String.downcase()
    else
      nil
    end

    %{
      "cl" => caveat.location,
      "cid" => caveat.caveat_id,
      "vid" => vid,
    }
  end

  defp decode_caveat(%{"cl" => cl, "cid" => cid, "vid" => nil}) do
    Types.Caveat.build(
      location: cl,
      caveat_id: cid,
      party: :first,
      verification_key_id: nil
    )
  end

  defp decode_caveat(%{"cl" => cl, "cid" => cid, "vid" => vid}) do
    verification_id = vid
    |> String.upcase()
    |> Base.decode16!()

    Types.Caveat.build(
      location: cl,
      caveat_id: cid,
      party: :third,
      verification_key_id: verification_id
    )
  end
end
