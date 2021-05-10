defmodule Macaroon.Types.Verification.VerifyParameters do
  @moduledoc """
  Struct module for Verification parameters
  """
  use TypedStruct
  use StructBuilder

  typedstruct do
    field(:predicates, list(String.t()), enforce: true, default: [])
    field(:callbacks, list(function()), enforce: true, default: [])
  end

  struct_builder()
end
