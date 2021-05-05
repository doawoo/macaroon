defmodule Macaroon.Types.Verification.VerifyError do
  use TypedStruct
  use StructBuilder

  @type err_type :: :caveat_not_met | :signature_not_matching | :discharge_not_found

  typedstruct do
    field(:type, err_type(), enforce: true, default: nil)
    field(:details, binary(), enforce: true, default: nil)
  end

  struct_builder()
end
