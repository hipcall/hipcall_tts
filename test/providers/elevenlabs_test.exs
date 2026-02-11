defmodule HipcallTts.Providers.ElevenLabsTest do
  use ExUnit.Case, async: false

  alias HipcallTts.Providers.ElevenLabs

  setup do
    bypass = Bypass.open()

    original_url = Application.get_env(:hipcall_tts, :elevenlabs_endpoint_url)

    Application.put_env(
      :hipcall_tts,
      :elevenlabs_endpoint_url,
      "http://localhost:#{bypass.port}/v1/text-to-speech"
    )

    # Clean up after test
    on_exit(fn ->
      if original_url do
        Application.put_env(:hipcall_tts, :elevenlabs_endpoint_url, original_url)
      else
        Application.delete_env(:hipcall_tts, :elevenlabs_endpoint_url)
      end
    end)

    {:ok, bypass: bypass}
  end

  describe "generate/1" do
    test "successfully generates audio with valid params", %{bypass: bypass} do
      audio_binary = <<255, 243, 68, 196, 0, 0, 0, 0, 0, 0, 0, 0>>
      voice_id = "21m00Tcm4TlvDq8ikWAM"

      Bypass.expect_once(bypass, "POST", "/v1/text-to-speech/#{voice_id}", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        # Assert the request is correct
        assert decoded["text"] == "Hello, world!"
        assert decoded["model_id"] == "eleven_multilingual_v2"
        assert decoded["output_format"] == "mp3_22050_32"

        # Verify headers
        assert Plug.Conn.get_req_header(conn, "xi-api-key") == ["test-key"]
        assert Plug.Conn.get_req_header(conn, "content-type") == ["application/json"]

        # Return success response with audio
        Plug.Conn.resp(conn, 200, audio_binary)
      end)

      params = [
        text: "Hello, world!",
        voice: voice_id,
        model: "eleven_multilingual_v2",
        api_key: "test-key"
      ]

      assert {:ok, ^audio_binary} = ElevenLabs.generate(params)
    end

    test "uses default model when model is not specified", %{bypass: bypass} do
      audio_binary = <<255, 243, 68, 196, 0, 0, 0, 0, 0, 0, 0, 0>>
      voice_id = "21m00Tcm4TlvDq8ikWAM"

      Bypass.expect_once(bypass, "POST", "/v1/text-to-speech/#{voice_id}", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        # Assert the default model is used
        assert decoded["model_id"] == "eleven_flash_v2_5"
        assert decoded["text"] == "Hello, world!"

        Plug.Conn.resp(conn, 200, audio_binary)
      end)

      params = [
        text: "Hello, world!",
        voice: voice_id,
        api_key: "test-key"
      ]

      assert {:ok, ^audio_binary} = ElevenLabs.generate(params)
    end

    test "handles API error responses", %{bypass: bypass} do
      voice_id = "21m00Tcm4TlvDq8ikWAM"

      error_body =
        Jason.encode!(%{
          "detail" => %{
            "message" => "Invalid API key"
          }
        })

      Bypass.expect_once(bypass, "POST", "/v1/text-to-speech/#{voice_id}", fn conn ->
        Plug.Conn.resp(conn, 401, error_body)
      end)

      params = [text: "Hello", voice: voice_id, api_key: "invalid-key"]

      assert {:error, error} = ElevenLabs.generate(params)
      assert error.message == "Invalid API key"
      assert error.code == :http_error
      assert error.status == 401
    end

    test "handles network errors", %{bypass: bypass} do
      Bypass.down(bypass)

      params = [text: "Hello", voice: "21m00Tcm4TlvDq8ikWAM", api_key: "test-key"]

      assert {:error, error} = ElevenLabs.generate(params)
      assert error.code == :network_error
      assert error.message =~ "Network error"
    end

    test "handles rate limit errors (429)", %{bypass: bypass} do
      voice_id = "21m00Tcm4TlvDq8ikWAM"

      error_body =
        Jason.encode!(%{
          "detail" => %{"message" => "Rate limit exceeded"}
        })

      Bypass.expect_once(bypass, "POST", "/v1/text-to-speech/#{voice_id}", fn conn ->
        Plug.Conn.resp(conn, 429, error_body)
      end)

      params = [text: "Hello", voice: voice_id, api_key: "test-key"]

      assert {:error, error} = ElevenLabs.generate(params)
      assert error.status == 429
    end

    test "uses format to determine output_format", %{bypass: bypass} do
      audio_binary = <<255, 243, 68, 196, 0, 0, 0, 0, 0, 0, 0, 0>>
      voice_id = "21m00Tcm4TlvDq8ikWAM"

      Bypass.expect_once(bypass, "POST", "/v1/text-to-speech/#{voice_id}", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["output_format"] == "pcm_22050"

        Plug.Conn.resp(conn, 200, audio_binary)
      end)

      params = [
        text: "Hello",
        voice: voice_id,
        format: "pcm",
        api_key: "test-key"
      ]

      assert {:ok, ^audio_binary} = ElevenLabs.generate(params)
    end
  end

  describe "validate_params/1" do
    test "returns :ok for valid params" do
      params = [text: "Hello, world!", voice: "21m00Tcm4TlvDq8ikWAM"]
      assert :ok = ElevenLabs.validate_params(params)
    end

    test "returns error for empty text" do
      params = [text: ""]
      assert {:error, "Text cannot be empty"} = ElevenLabs.validate_params(params)
    end

    test "returns error for text exceeding max length" do
      long_text = String.duplicate("a", 50000)
      params = [text: long_text]

      assert {:error, error} = ElevenLabs.validate_params(params)
      assert error =~ "exceeds maximum length"
    end

    test "validates model-specific max length" do
      # eleven_multilingual_v2 has max 10000 characters
      long_text = String.duplicate("a", 11000)
      params = [text: long_text, model: "eleven_multilingual_v2"]

      assert {:error, error} = ElevenLabs.validate_params(params)
      assert error =~ "exceeds maximum length"
      assert error =~ "10000"
      assert error =~ "eleven_multilingual_v2"
    end

    test "returns error for invalid format" do
      params = [text: "Hello", format: "invalid-format"]
      assert {:error, error} = ElevenLabs.validate_params(params)
      assert error =~ "Invalid format"
    end

    test "returns error for invalid model" do
      params = [text: "Hello", model: "invalid-model"]
      assert {:error, "Invalid model: invalid-model"} = ElevenLabs.validate_params(params)
    end
  end

  describe "models/0" do
    test "returns list of available models" do
      models = ElevenLabs.models()
      assert is_list(models)
      assert length(models) == 2
      assert Enum.any?(models, &(&1.id == "eleven_multilingual_v2"))
      assert Enum.any?(models, &(&1.id == "eleven_flash_v2_5"))
    end

    test "models have language information" do
      models = ElevenLabs.models()
      multilingual_v2 = Enum.find(models, &(&1.id == "eleven_multilingual_v2"))
      assert multilingual_v2.languages != nil
      assert is_list(multilingual_v2.languages)
      assert "en" in multilingual_v2.languages
      assert "es" in multilingual_v2.languages
    end
  end

  describe "voices/0" do
    test "returns list of available voices" do
      voices = ElevenLabs.voices()
      assert is_list(voices)
      assert length(voices) == 7
      assert Enum.any?(voices, &(&1.id == "Xb7hH8MSUJpSbSDYk0k2"))
      assert Enum.any?(voices, &(&1.id == "nPczCjzI2devNBz1zQrb"))
      assert Enum.any?(voices, &(&1.id == "N2lVS1w4EtoT3dr4eOWO"))
      assert Enum.any?(voices, &(&1.id == "KbaseEXyT9EE0CQLEfbB"))
      assert Enum.any?(voices, &(&1.id == "IuRRIAcbQK5AQk1XevPj"))
      assert Enum.any?(voices, &(&1.id == "zCagxWNd7QOsCjiHDrGR"))
      assert Enum.any?(voices, &(&1.id == "Q5n6GDIjpN0pLOlycRFT"))
    end

    test "Alice is the default voice" do
      voices = ElevenLabs.voices()
      alice = Enum.find(voices, &(&1.id == "Xb7hH8MSUJpSbSDYk0k2"))
      assert alice != nil
      assert alice.name == "Alice"
      assert alice.gender == :female
      assert is_list(alice.language)
      assert "en" in alice.language
    end

    test "voices have correct properties" do
      voices = ElevenLabs.voices()

      brian = Enum.find(voices, &(&1.id == "nPczCjzI2devNBz1zQrb"))
      assert brian != nil
      assert brian.name == "Brian"
      assert brian.gender == :male
      assert is_list(brian.language)
      assert "en" in brian.language

      belma = Enum.find(voices, &(&1.id == "KbaseEXyT9EE0CQLEfbB"))
      assert belma != nil
      assert belma.name == "Belma"
      assert belma.gender == :female
      assert is_list(belma.language)
      assert "tr" in belma.language

      ipek = Enum.find(voices, &(&1.id == "zCagxWNd7QOsCjiHDrGR"))
      assert ipek != nil
      assert ipek.name == "İpek"
      assert ipek.gender == :female
      assert ipek.language == "tr"
    end
  end

  describe "languages/0" do
    test "returns list of supported languages" do
      languages = ElevenLabs.languages()
      assert is_list(languages)
      assert Enum.any?(languages, &(&1.code == "en"))
      assert Enum.any?(languages, &(&1.code == "es"))
      assert Enum.any?(languages, &(&1.code == "fr"))
    end
  end

  describe "capabilities/0" do
    test "returns provider capabilities" do
      caps = ElevenLabs.capabilities()
      assert caps.streaming == false
      assert "mp3" in caps.formats
      assert "pcm" in caps.formats
      assert caps.max_text_length == 40000
    end
  end

  describe "stream/1" do
    test "returns not implemented error" do
      assert {:error, err} = ElevenLabs.stream(text: "Hello")
      assert err.code == :not_implemented
      assert err.message == "Streaming not yet implemented"
      assert err.provider == :elevenlabs
    end
  end
end
