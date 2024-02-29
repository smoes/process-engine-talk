defmodule ProcessEngineTalkTest do
  use ExUnit.Case
  doctest ProcessEngineTalk

  test "greets the world" do
    assert ProcessEngineTalk.hello() == :world
  end
end
