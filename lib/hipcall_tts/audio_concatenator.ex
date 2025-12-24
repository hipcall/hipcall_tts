defmodule HipcallTts.AudioConcatenator do
  @moduledoc """
  Concatenates audio segments.

  For MP3, simple binary concatenation usually works for sequential playback.
  """

  @spec concatenate([binary()]) :: {:ok, binary()} | {:error, String.t()}
  def concatenate([]), do: {:ok, <<>>}
  def concatenate([single]) when is_binary(single), do: {:ok, single}

  def concatenate(segments) when is_list(segments) do
    if Enum.all?(segments, &is_binary/1) do
      {:ok, IO.iodata_to_binary(segments)}
    else
      {:error, "all segments must be binaries"}
    end
  end

  def concatenate(_), do: {:error, "segments must be a list of binaries"}
end
