defmodule Macaroon.Types.Verification.VerifyContext do
  use TypedStruct
  use StructBuilder

  alias Macaroon.Types.Macaroon
  alias Macaroon.Types.Verification.VerifyError
  alias Macaroon.Types.Verification.VerifyParameters

  typedstruct do
    field(:key, binary(), enforce: true, default: nil)
    field(:calculated_signature, binary(), enforce: true, default: nil)
    field(:parameters, VerifyParameters.t(), enforce: true, default: nil)
    field(:errors, list(VerifyError.t()), enforce: true, default: [])
    field(:discharges, list(Macaroon.t()), enforce: true, default: [])
  end

  struct_builder()
end
