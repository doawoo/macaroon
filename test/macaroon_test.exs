defmodule MacaroonTest do
  use ExUnit.Case
  doctest Macaroon

  test "greets the world" do
    assert Macaroon.hello() == :world
  end
end
