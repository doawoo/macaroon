defmodule Macaroon.Types.Verification.VerifyParameters do
  use TypedStruct
  use StructBuilder

  typedstruct do
    field :predicates, list(String.t()), enforce: true, default: []
    field :callbacks, list(function()), enforce: true, default: []
  end

  struct_builder()
end
