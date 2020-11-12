defmodule StructBuilder do
  @moduledoc """
  This module defines a macro to be used in modules that provide a typedstruct.
  Calling the `struct_builder()` macro inside the module will define a `build/1` function on
  the module.
  """

  @spec __using__(any) ::
          {:import, [{:context, StructBuilder}, ...], [{:__aliases__, [...], [...]}, ...]}
  defmacro __using__(_opts) do
    quote do
      import StructBuilder
    end
  end

  @spec struct_builder :: {:__block__, [{:generated, true}, ...], [{:def, [...], [...]}, ...]}
  defmacro struct_builder() do
    quote generated: true do
      def build(attrs) when is_list(attrs) do
        filtered = Enum.filter(attrs, fn {_k, v} -> !is_nil(v) end)
        struct(unquote(__CALLER__.module), filtered)
      end

      def build() do
        struct(unquote(__CALLER__.module), [])
      end
    end
  end
end
