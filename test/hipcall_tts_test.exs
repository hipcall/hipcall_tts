defmodule HipcallTtsTest do
  use ExUnit.Case
  doctest HipcallTts

  test "generate/1" do
    assert HipcallTts.generate() == {:error, "Not implemented yet"}
  end
end
