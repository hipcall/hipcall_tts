defmodule HipcallTts.TextSplitter do
  @moduledoc """
  Splits text into chunks that fit within a provider max length, preferring
  sentence boundaries when possible.
  """

  alias HipcallTts.Telemetry

  @sentence_boundary_regex ~r/(?<=[.!?…。！？؟])\s+/u

  @spec split(String.t(), pos_integer(), keyword()) :: {:ok, [String.t()]} | {:error, String.t()}
  def split(text, max_length, telemetry_meta \\ [])

  def split(text, _max_length, _telemetry_meta) when not is_binary(text) do
    {:error, "text must be a string"}
  end

  def split(_text, max_length, _telemetry_meta)
      when not (is_integer(max_length) and max_length > 0) do
    {:error, "max_length must be a positive integer"}
  end

  def split(text, max_length, telemetry_meta) do
    text = String.trim(text)

    cond do
      text == "" ->
        {:ok, []}

      String.length(text) <= max_length ->
        {:ok, [text]}

      true ->
        sentences = Regex.split(@sentence_boundary_regex, text, trim: true)

        chunks =
          sentences
          |> Enum.flat_map(&split_oversized_sentence(&1, max_length))
          |> group_by_length(max_length)

        if length(chunks) > 1 do
          Telemetry.text_split(
            length(chunks),
            Keyword.merge(
              [
                original_length: String.length(text),
                chunk_size: max_length,
                total_length: total_len(chunks)
              ],
              telemetry_meta
            )
          )
        end

        {:ok, chunks}
    end
  end

  defp group_by_length(parts, max_length) do
    {acc, current} =
      Enum.reduce(parts, {[], ""}, fn part, {acc, current} ->
        part = String.trim(part)

        cond do
          part == "" ->
            {acc, current}

          current == "" and String.length(part) <= max_length ->
            {acc, part}

          String.length(current) + 1 + String.length(part) <= max_length ->
            {acc, current <> " " <> part}

          true ->
            acc = if current == "", do: acc, else: [current | acc]
            {acc, part}
        end
      end)

    acc =
      if current == "" do
        acc
      else
        [current | acc]
      end

    acc
    |> Enum.reverse()
    |> Enum.reject(&(&1 == ""))
  end

  defp split_oversized_sentence(sentence, max_length) do
    sentence = String.trim(sentence)

    if String.length(sentence) <= max_length do
      [sentence]
    else
      sentence
      |> String.graphemes()
      |> Enum.chunk_every(max_length)
      |> Enum.map(&Enum.join/1)
    end
  end

  defp total_len(chunks), do: Enum.reduce(chunks, 0, fn c, acc -> acc + String.length(c) end)
end
