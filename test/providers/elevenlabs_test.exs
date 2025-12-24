defmodule HipcallTts.Providers.ElevenLabsTest do
  use ExUnit.Case, async: true

  alias HipcallTts.Providers.ElevenLabs

  test "stub returns not_implemented for generate/stream/validate_params" do
    assert {:error, %{code: :not_implemented, provider: :elevenlabs}} =
             ElevenLabs.generate(text: "hi")

    assert {:error, %{code: :not_implemented, provider: :elevenlabs}} =
             ElevenLabs.stream(text: "hi")

    assert {:error, %{code: :not_implemented, provider: :elevenlabs}} =
             ElevenLabs.validate_params(text: "hi")
  end

  test "stub introspection functions are safe" do
    assert ElevenLabs.models() == []
    assert ElevenLabs.voices() == []
    assert ElevenLabs.languages() == []

    caps = ElevenLabs.capabilities()
    assert caps.streaming == false
    assert "mp3" in caps.formats
  end
end
