defmodule HipcallTts.Providers.OpenAITest do
  use ExUnit.Case, async: false

  alias HipcallTts.Providers.OpenAI

  setup do
    bypass = Bypass.open()

    original_url = Application.get_env(:hipcall_tts, :openai_endpoint_url)

    Application.put_env(
      :hipcall_tts,
      :openai_endpoint_url,
      "http://localhost:#{bypass.port}/v1/audio/speech"
    )

    # Clean up after test
    on_exit(fn ->
      if original_url do
        Application.put_env(:hipcall_tts, :openai_endpoint_url, original_url)
      else
        Application.delete_env(:hipcall_tts, :openai_endpoint_url)
      end
    end)

    {:ok, bypass: bypass}
  end

  describe "generate/1" do
    test "successfully generates audio with valid params", %{bypass: bypass} do
      audio_binary = <<255, 243, 68, 196, 0, 0, 0, 0, 0, 0, 0, 0>>

      Bypass.expect_once(bypass, "POST", "/v1/audio/speech", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        # Assert the request is correct
        assert decoded["model"] == "tts-1"
        assert decoded["input"] == "Hello, world!"
        assert decoded["voice"] == "nova"
        assert decoded["response_format"] == "mp3"

        # Verify headers
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-key"]
        assert Plug.Conn.get_req_header(conn, "content-type") == ["application/json"]

        # Return success response with audio
        Plug.Conn.resp(conn, 200, audio_binary)
      end)

      params = [
        text: "Hello, world!",
        voice: "nova",
        model: "tts-1",
        api_key: "test-key"
      ]

      assert {:ok, ^audio_binary} = OpenAI.generate(params)
    end

    test "handles API error responses", %{bypass: bypass} do
      error_body =
        Jason.encode!(%{
          "error" => %{
            "message" => "Invalid API key",
            "type" => "invalid_request_error"
          }
        })

      Bypass.expect_once(bypass, "POST", "/v1/audio/speech", fn conn ->
        Plug.Conn.resp(conn, 401, error_body)
      end)

      params = [text: "Hello", api_key: "invalid-key"]

      assert {:error, error} = OpenAI.generate(params)
      assert error.message == "Invalid API key"
      assert error.code == :http_error
      assert error.status == 401
    end

    test "handles network errors", %{bypass: bypass} do
      Bypass.down(bypass)

      params = [text: "Hello", api_key: "test-key"]

      assert {:error, error} = OpenAI.generate(params)
      assert error.code == :network_error
      assert error.message =~ "Network error"
    end

    test "handles rate limit errors (429)", %{bypass: bypass} do
      error_body =
        Jason.encode!(%{
          "error" => %{"message" => "Rate limit exceeded"}
        })

      Bypass.expect_once(bypass, "POST", "/v1/audio/speech", fn conn ->
        Plug.Conn.resp(conn, 429, error_body)
      end)

      params = [text: "Hello", api_key: "test-key"]

      assert {:error, error} = OpenAI.generate(params)
      assert error.status == 429
    end
  end

  describe "validate_params/1" do
    test "returns :ok for valid params" do
      params = [text: "Hello, world!", voice: "nova"]
      assert :ok = OpenAI.validate_params(params)
    end

    test "returns error for empty text" do
      params = [text: ""]
      assert {:error, "Text cannot be empty"} = OpenAI.validate_params(params)
    end

    test "returns error for text exceeding max length" do
      long_text = String.duplicate("a", 5000)
      params = [text: long_text]

      assert {:error, error} = OpenAI.validate_params(params)
      assert error =~ "exceeds maximum length"
    end

    test "returns error for invalid voice" do
      params = [text: "Hello", voice: "invalid-voice"]
      assert {:error, "Invalid voice: invalid-voice"} = OpenAI.validate_params(params)
    end

    test "returns error for invalid model" do
      params = [text: "Hello", model: "invalid-model"]
      assert {:error, "Invalid model: invalid-model"} = OpenAI.validate_params(params)
    end
  end

  describe "models/0" do
    test "returns list of available models" do
      models = OpenAI.models()
      assert is_list(models)
      assert length(models) == 2
      assert Enum.any?(models, &(&1.id == "tts-1"))
      assert Enum.any?(models, &(&1.id == "tts-1-hd"))
    end
  end

  describe "voices/0" do
    test "returns list of available voices" do
      voices = OpenAI.voices()
      assert is_list(voices)
      assert length(voices) == 6
      assert Enum.any?(voices, &(&1.id == "nova"))
      assert Enum.any?(voices, &(&1.id == "alloy"))
    end
  end

  describe "languages/0" do
    test "returns list of supported languages" do
      languages = OpenAI.languages()
      assert is_list(languages)
      assert Enum.any?(languages, &(&1.code == "en"))
      assert Enum.any?(languages, &(&1.code == "tr"))
    end
  end

  describe "capabilities/0" do
    test "returns provider capabilities" do
      caps = OpenAI.capabilities()
      assert caps.streaming == false
      assert "mp3" in caps.formats
      assert caps.max_text_length == 4096
    end
  end

  describe "stream/1" do
    test "returns not implemented error" do
      assert {:error, "Streaming not yet implemented"} = OpenAI.stream(text: "Hello")
    end
  end
end
