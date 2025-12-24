defmodule HipcallTts.AudioConcatenatorTest do
  use ExUnit.Case, async: true

  alias HipcallTts.AudioConcatenator

  test "empty list returns empty binary" do
    assert {:ok, <<>>} = AudioConcatenator.concatenate([])
  end

  test "single item returns itself" do
    assert {:ok, "abc"} = AudioConcatenator.concatenate(["abc"])
  end

  test "multiple segments are concatenated" do
    assert {:ok, "ab" <> "cd"} = AudioConcatenator.concatenate(["ab", "cd"])
  end

  test "rejects non-binary segments" do
    assert {:error, _} = AudioConcatenator.concatenate(["ok", 123])
  end
end
