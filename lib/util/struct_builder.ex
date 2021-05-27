# coveralls-ignore-start
defmodule StructBuilder do
  @moduledoc false
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
# coveralls-ignore-stop
