defmodule Macaroon.Types.Macaroon do
  @moduledoc """
  Struct module for base Macaroon type
  """
  use TypedStruct
  use StructBuilder

  alias Macaroon.Types.Caveat

  typedstruct do
    field(:location, String.t(), enforce: true, default: "")
    field(:public_identifier, String.t(), enforce: true, default: "")
    field(:signature, String.t(), enforce: true, default: nil)
    field(:first_party_caveats, list(Caveat.t()), enforce: true, default: [])
    field(:third_party_caveats, list(Caveat.t()), enforce: true, default: [])
  end

  struct_builder()
end
