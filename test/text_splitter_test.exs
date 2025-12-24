defmodule HipcallTts.TextSplitterTest do
  use ExUnit.Case, async: true

  alias HipcallTts.TextSplitter

  test "returns [] for empty string" do
    assert {:ok, []} = TextSplitter.split("", 10)
    assert {:ok, []} = TextSplitter.split("   ", 10)
  end

  test "does not split when under max length" do
    assert {:ok, ["hello"]} = TextSplitter.split("hello", 10)
  end

  test "splits by sentence boundaries" do
    text = "Hello world. How are you? Fine!"
    assert {:ok, chunks} = TextSplitter.split(text, 15)
    assert Enum.all?(chunks, &(String.length(&1) <= 15))
    assert Enum.join(chunks, " ") == "Hello world. How are you? Fine!"
  end

  test "hard-splits very long sentence" do
    text = String.duplicate("a", 25)
    assert {:ok, chunks} = TextSplitter.split(text, 10)

    assert chunks == [
             String.duplicate("a", 10),
             String.duplicate("a", 10),
             String.duplicate("a", 5)
           ]
  end
end
