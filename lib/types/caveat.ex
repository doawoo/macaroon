defmodule Macaroon.Types.Caveat do
  use TypedStruct
  use StructBuilder

  typedstruct do
    field(:caveat_id, String.t(), enforce: true, default: nil)
    field(:location, String.t(), enforce: true, default: nil)
    field(:verification_key_id, String.t(), enforce: true, default: nil)
    field(:party, :first | :third, enforce: true, default: :first)
  end

  struct_builder()
end
