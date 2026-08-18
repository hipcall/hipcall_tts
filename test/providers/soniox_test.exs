defmodule HipcallTts.Providers.SonioxTest do
  use ExUnit.Case, async: false

  alias HipcallTts.Providers.Soniox

  setup do
    bypass = Bypass.open()

    original_url = Application.get_env(:hipcall_tts, :soniox_endpoint_url)
    original_max = Application.get_env(:hipcall_tts, :soniox_max_text_length)

    Application.put_env(
      :hipcall_tts,
      :soniox_endpoint_url,
      "http://localhost:#{bypass.port}/tts"
    )

    on_exit(fn ->
      if original_url do
        Application.put_env(:hipcall_tts, :soniox_endpoint_url, original_url)
      else
        Application.delete_env(:hipcall_tts, :soniox_endpoint_url)
      end

      if original_max do
        Application.put_env(:hipcall_tts, :soniox_max_text_length, original_max)
      else
        Application.delete_env(:hipcall_tts, :soniox_max_text_length)
      end
    end)

    {:ok, bypass: bypass}
  end

  describe "generate/1" do
    test "successfully generates audio with valid params", %{bypass: bypass} do
      audio_binary = <<255, 243, 68, 196, 0, 0, 0, 0, 0, 0, 0, 0>>

      Bypass.expect_once(bypass, "POST", "/tts", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["model"] == "tts-rt-v2"
        assert decoded["text"] == "Merhaba dünya!"
        assert decoded["voice"] == "Mina"
        assert decoded["language"] == "tr"
        assert decoded["audio_format"] == "mp3"

        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-key"]
        assert Plug.Conn.get_req_header(conn, "content-type") == ["application/json"]

        Plug.Conn.resp(conn, 200, audio_binary)
      end)

      params = [
        text: "Merhaba dünya!",
        voice: "Mina",
        model: "tts-rt-v2",
        language: "tr",
        api_key: "test-key"
      ]

      assert {:ok, ^audio_binary} = Soniox.generate(params)
    end

    test "normalizes locale-style language to the bare ISO code", %{bypass: bypass} do
      # The TTS service sends "tr-TR"/"en-US"; Soniox rejects those with a 400.
      Bypass.expect_once(bypass, "POST", "/tts", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body)["language"] == "tr"
        Plug.Conn.resp(conn, 200, "audio")
      end)

      assert {:ok, "audio"} =
               Soniox.generate(text: "Merhaba", language: "tr-TR", api_key: "test-key")
    end

    test "normalizes underscore locales", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/tts", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body)["language"] == "en"
        Plug.Conn.resp(conn, 200, "audio")
      end)

      assert {:ok, "audio"} =
               Soniox.generate(text: "Hello", language: "en_US", api_key: "test-key")
    end

    test "maps package formats onto Soniox audio_format values", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/tts", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body)["audio_format"] == "pcm_s16le"
        Plug.Conn.resp(conn, 200, "audio")
      end)

      assert {:ok, "audio"} =
               Soniox.generate(text: "Hello", language: "en", format: "pcm", api_key: "test-key")
    end

    test "omits the schema default sample rate that Soniox rejects", %{bypass: bypass} do
      # HipcallTts.Schema defaults :sample_rate to 22050, which Soniox accepts
      # for no format at all. It must not be forwarded.
      Bypass.expect_once(bypass, "POST", "/tts", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        refute Map.has_key?(Jason.decode!(body), "sample_rate")
        Plug.Conn.resp(conn, 200, "audio")
      end)

      assert {:ok, "audio"} =
               Soniox.generate(
                 text: "Hello",
                 language: "en",
                 sample_rate: 22050,
                 api_key: "test-key"
               )
    end

    test "forwards a sample rate the chosen format supports", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/tts", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body)["sample_rate"] == 44100
        Plug.Conn.resp(conn, 200, "audio")
      end)

      assert {:ok, "audio"} =
               Soniox.generate(
                 text: "Hello",
                 language: "en",
                 format: "mp3",
                 sample_rate: 44100,
                 api_key: "test-key"
               )
    end

    test "drops a sample rate the chosen format does not support", %{bypass: bypass} do
      # mp3 supports 16k/24k/32k/44.1k/48k but not 8000.
      Bypass.expect_once(bypass, "POST", "/tts", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        refute Map.has_key?(Jason.decode!(body), "sample_rate")
        Plug.Conn.resp(conn, 200, "audio")
      end)

      assert {:ok, "audio"} =
               Soniox.generate(
                 text: "Hello",
                 language: "en",
                 format: "mp3",
                 sample_rate: 8000,
                 api_key: "test-key"
               )
    end

    test "omits speed when it is the default", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/tts", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        refute Map.has_key?(Jason.decode!(body), "speed")
        Plug.Conn.resp(conn, 200, "audio")
      end)

      assert {:ok, "audio"} =
               Soniox.generate(text: "Hello", language: "en", speed: 1.0, api_key: "test-key")
    end

    test "forwards a non-default speed", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/tts", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body)["speed"] == 1.2
        Plug.Conn.resp(conn, 200, "audio")
      end)

      assert {:ok, "audio"} =
               Soniox.generate(text: "Hello", language: "en", speed: 1.2, api_key: "test-key")
    end

    test "forwards reduce_silence when given", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/tts", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body)["reduce_silence"] == true
        Plug.Conn.resp(conn, 200, "audio")
      end)

      assert {:ok, "audio"} =
               Soniox.generate(
                 text: "Hello",
                 language: "en",
                 reduce_silence: true,
                 api_key: "test-key"
               )
    end

    test "omits reduce_silence when not given", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/tts", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        refute Map.has_key?(Jason.decode!(body), "reduce_silence")
        Plug.Conn.resp(conn, 200, "audio")
      end)

      assert {:ok, "audio"} = Soniox.generate(text: "Hello", language: "en", api_key: "test-key")
    end

    test "forwards a bitrate the chosen format supports", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/tts", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body)["bitrate"] == 32_000
        Plug.Conn.resp(conn, 200, "audio")
      end)

      assert {:ok, "audio"} =
               Soniox.generate(
                 text: "Hello",
                 language: "en",
                 format: "mp3",
                 bitrate: 32_000,
                 api_key: "test-key"
               )
    end

    test "does not forward a bitrate to a lossless format", %{bypass: bypass} do
      # Soniox rejects `bitrate` outright for wav/flac/pcm with a 400.
      Bypass.expect_once(bypass, "POST", "/tts", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        refute Map.has_key?(Jason.decode!(body), "bitrate")
        Plug.Conn.resp(conn, 200, "audio")
      end)

      assert {:ok, "audio"} =
               Soniox.generate(
                 text: "Hello",
                 language: "en",
                 format: "wav",
                 api_key: "test-key"
               )
    end

    test "audio tags ride along in the text unchanged", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/tts", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body)["text"] == "[warm] Merhaba. [calm] Talebiniz inceleniyor."
        Plug.Conn.resp(conn, 200, "audio")
      end)

      assert {:ok, "audio"} =
               Soniox.generate(
                 text: "[warm] Merhaba. [calm] Talebiniz inceleniyor.",
                 language: "tr",
                 api_key: "test-key"
               )
    end

    test "provider_opts carry Soniox-only options through HipcallTts.generate/1",
         %{bypass: bypass} do
      # `:reduce_silence` and `:bitrate` are not in HipcallTts.Schema, so
      # `provider_opts` is the only way to reach them.
      Bypass.expect_once(bypass, "POST", "/tts", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["reduce_silence"] == true
        assert decoded["bitrate"] == 64_000
        assert decoded["language"] == "tr"

        Plug.Conn.resp(conn, 200, "audio")
      end)

      assert {:ok, "audio"} =
               HipcallTts.generate(
                 provider: :soniox,
                 text: "Merhaba",
                 language: "tr-TR",
                 format: "mp3",
                 provider_opts: [reduce_silence: true, bitrate: 64_000, api_key: "test-key"]
               )
    end

    test "handles API error responses", %{bypass: bypass} do
      error_body =
        Jason.encode!(%{
          "error_code" => 400,
          "error_message" => "Invalid voice 'Nonexistent' for model 'tts-rt-v2'.",
          "error_type" => "invalid_request"
        })

      Bypass.expect_once(bypass, "POST", "/tts", fn conn ->
        Plug.Conn.resp(conn, 400, error_body)
      end)

      assert {:error, error} = Soniox.generate(text: "Hello", language: "en", api_key: "bad-key")
      assert error.message == "Invalid voice 'Nonexistent' for model 'tts-rt-v2'."
      assert error.code == :http_error
      assert error.status == 400
    end

    test "falls back to a generic message for unparseable error bodies", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/tts", fn conn ->
        Plug.Conn.resp(conn, 502, "<html>bad gateway</html>")
      end)

      assert {:error, error} = Soniox.generate(text: "Hello", language: "en", api_key: "test-key")
      assert error.message == "HTTP 502"
      assert error.status == 502
    end

    test "handles network errors", %{bypass: bypass} do
      Bypass.down(bypass)

      assert {:error, error} = Soniox.generate(text: "Hello", language: "en", api_key: "test-key")
      assert error.code == :network_error
      assert error.message =~ "Network error"
    end

    test "handles rate limit errors (429)", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/tts", fn conn ->
        Plug.Conn.resp(conn, 429, Jason.encode!(%{"error_message" => "Rate limit exceeded"}))
      end)

      assert {:error, error} = Soniox.generate(text: "Hello", language: "en", api_key: "test-key")
      assert error.status == 429
      assert error.message == "Rate limit exceeded"
    end
  end

  describe "validate_params/1" do
    test "returns :ok for valid params" do
      assert :ok = Soniox.validate_params(text: "Merhaba", voice: "Mina", language: "tr")
    end

    test "accepts locale-style languages" do
      assert :ok = Soniox.validate_params(text: "Merhaba", language: "tr-TR")
    end

    test "returns error for empty text" do
      assert {:error, "Text cannot be empty"} = Soniox.validate_params(text: "")
    end

    test "returns error for text exceeding max length" do
      long_text = String.duplicate("a", 5000)

      assert {:error, error} = Soniox.validate_params(text: long_text)
      assert error =~ "exceeds maximum length"
    end

    test "returns error for invalid voice" do
      assert {:error, "Invalid voice: invalid-voice"} =
               Soniox.validate_params(text: "Hello", voice: "invalid-voice")
    end

    test "returns error for invalid model" do
      assert {:error, "Invalid model: tts-rt-v9"} =
               Soniox.validate_params(text: "Hello", model: "tts-rt-v9")
    end

    test "returns error for an unsupported language" do
      assert {:error, "Invalid language: zz-ZZ"} =
               Soniox.validate_params(text: "Hello", language: "zz-ZZ")
    end

    test "returns error for a format Soniox cannot produce" do
      assert {:error, "Invalid format: ogg_vorbis"} =
               Soniox.validate_params(text: "Hello", language: "en", format: "ogg_vorbis")
    end

    test "rejects a bitrate the format does not support" do
      assert {:error, error} =
               Soniox.validate_params(text: "Hello", format: "mp3", bitrate: 48_000)

      assert error =~ "Invalid bitrate for mp3"
      assert error =~ "32000"

      assert :ok = Soniox.validate_params(text: "Hello", format: "mp3", bitrate: 128_000)
    end

    test "rejects a bitrate on a lossless format" do
      assert {:error, "Bitrate is not supported for the wav format"} =
               Soniox.validate_params(text: "Hello", format: "wav", bitrate: 128_000)

      assert {:error, "Bitrate is not supported for the pcm_s16le format"} =
               Soniox.validate_params(text: "Hello", format: "pcm", bitrate: 128_000)
    end

    test "rejects a non-boolean reduce_silence" do
      assert {:error, "reduce_silence must be a boolean"} =
               Soniox.validate_params(text: "Hello", reduce_silence: "yes")

      assert :ok = Soniox.validate_params(text: "Hello", reduce_silence: true)
      assert :ok = Soniox.validate_params(text: "Hello", reduce_silence: false)
    end

    test "rejects speed outside the model range" do
      # Soniox accepts 0.7..1.3; the package schema allows a much wider range.
      assert {:error, error} = Soniox.validate_params(text: "Hello", speed: 2.0)
      assert error =~ "Speed must be between 0.7 and 1.3"

      assert {:error, _} = Soniox.validate_params(text: "Hello", speed: 0.5)
      assert :ok = Soniox.validate_params(text: "Hello", speed: 0.7)
      assert :ok = Soniox.validate_params(text: "Hello", speed: 1.3)
    end
  end

  describe "models/0" do
    test "exposes only the current model" do
      models = Soniox.models()
      assert length(models) == 1
      assert hd(models).id == "tts-rt-v2"
      # tts-rt-v1 was removed by Soniox on 2026-08-31 and must not be offered.
      refute Enum.any?(models, &(&1.id == "tts-rt-v1"))
    end
  end

  describe "voices/0" do
    test "returns the full v2 voice catalog" do
      voices = Soniox.voices()
      assert length(voices) == 70
      assert Enum.any?(voices, &(&1.id == "Mina"))
      assert Enum.any?(voices, &(&1.id == "Daniel"))

      mina = Enum.find(voices, &(&1.id == "Mina"))
      assert mina.gender == :female
      assert is_list(mina.language)
      assert "tr" in mina.language
      assert "en" in mina.language
    end

    test "every voice carries gender and supported_models" do
      for voice <- Soniox.voices() do
        assert voice.gender in [:male, :female, :neutral], "#{voice.id} has no gender"
        assert voice.supported_models == ["tts-rt-v2"], "#{voice.id} missing supported_models"
      end
    end
  end

  describe "compatible_models/1" do
    test "returns all models for any known voice" do
      all_models = Soniox.models()

      for voice <- Soniox.voices() do
        assert Soniox.compatible_models(voice.id) == all_models
      end
    end

    test "returns all models for unknown voice" do
      assert Soniox.compatible_models("unknown-voice") == Soniox.models()
    end
  end

  describe "languages/0" do
    test "returns the supported language list" do
      languages = Soniox.languages()
      assert length(languages) == 63
      assert Enum.any?(languages, &(&1.code == "tr"))
      assert Enum.any?(languages, &(&1.code == "en"))
      assert Enum.any?(languages, &(&1.code == "ja"))
    end
  end

  describe "capabilities/0" do
    test "returns provider capabilities" do
      caps = Soniox.capabilities()
      assert caps.streaming == false
      assert "mp3" in caps.formats
      refute "ogg_vorbis" in caps.formats
      assert caps.max_text_length == 1100
    end

    test "max_text_length is configurable for dense scripts" do
      # Soniox caps audio at 2 minutes of duration, and CJK packs far more
      # speech into the same character count, so deployments must be able to
      # lower the split threshold.
      Application.put_env(:hipcall_tts, :soniox_max_text_length, 450)

      assert Soniox.capabilities().max_text_length == 450
      assert {:error, error} = Soniox.validate_params(text: String.duplicate("字", 500))
      assert error =~ "exceeds maximum length of 450"
    end
  end

  describe "stream/1" do
    test "returns not implemented error" do
      assert {:error, "Streaming not yet implemented"} = Soniox.stream(text: "Hello")
    end
  end
end
