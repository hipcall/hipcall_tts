defmodule HipcallTtsTest do
  use ExUnit.Case, async: false

  setup do
    bypass = Bypass.open()

    original_url = Application.get_env(:hipcall_tts, :openai_endpoint_url)

    Application.put_env(
      :hipcall_tts,
      :openai_endpoint_url,
      "http://localhost:#{bypass.port}/v1/audio/speech"
    )

    on_exit(fn ->
      if original_url do
        Application.put_env(:hipcall_tts, :openai_endpoint_url, original_url)
      else
        Application.delete_env(:hipcall_tts, :openai_endpoint_url)
      end
    end)

    {:ok, bypass: bypass}
  end

  test "generate/1 returns audio for short text", %{bypass: bypass} do
    audio_binary = <<255, 243, 1, 2, 3, 4>>

    Bypass.expect_once(bypass, "POST", "/v1/audio/speech", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)

      assert decoded["input"] == "Hello"

      conn
      |> Plug.Conn.put_resp_content_type("audio/mpeg")
      |> Plug.Conn.resp(200, audio_binary)
    end)

    assert {:ok, ^audio_binary} =
             HipcallTts.generate(
               provider: :openai,
               text: "Hello",
               api_key: "test-key",
               voice: "nova"
             )
  end

  test "generate/1 auto-splits long text and concatenates results", %{bypass: bypass} do
    text = String.duplicate("a", 5000)
    audio1 = "AUDIO1-"
    audio2 = "-AUDIO2"

    {:ok, counter} = Agent.start_link(fn -> 0 end)

    Bypass.expect(bypass, "POST", "/v1/audio/speech", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      input = decoded["input"]

      n = Agent.get_and_update(counter, fn n -> {n, n + 1} end)

      cond do
        n == 0 ->
          assert String.length(input) == 4096
          Plug.Conn.resp(conn, 200, audio1)

        n == 1 ->
          assert String.length(input) == 904
          Plug.Conn.resp(conn, 200, audio2)

        true ->
          Plug.Conn.resp(conn, 500, "unexpected extra call")
      end
    end)

    assert {:ok, audio} =
             HipcallTts.generate(
               provider: :openai,
               text: text,
               api_key: "test-key",
               voice: "nova"
             )

    assert audio == audio1 <> audio2
  end

  test "generate/1 retries provider errors based on retry_opts", %{bypass: bypass} do
    {:ok, counter} = Agent.start_link(fn -> 0 end)
    audio = "OK"

    Bypass.expect(bypass, "POST", "/v1/audio/speech", fn conn ->
      n = Agent.get_and_update(counter, fn n -> {n, n + 1} end)

      if n == 0 do
        Plug.Conn.resp(conn, 429, Jason.encode!(%{"error" => %{"message" => "Rate limit"}}))
      else
        Plug.Conn.resp(conn, 200, audio)
      end
    end)

    assert {:ok, ^audio} =
             HipcallTts.generate(
               provider: :openai,
               text: "Hello",
               api_key: "test-key",
               voice: "nova",
               retry_opts: [max_attempts: 1, initial_delay: 0, max_delay: 0]
             )
  end

  test "introspection functions delegate to providers" do
    assert :openai in HipcallTts.providers()

    assert {:ok, models} = HipcallTts.models(:openai)
    assert is_list(models)

    assert {:ok, voices} = HipcallTts.voices(:openai)
    assert is_list(voices)

    assert {:ok, languages} = HipcallTts.languages(:openai)
    assert is_list(languages)

    assert {:ok, caps} = HipcallTts.capabilities(:openai)
    assert is_map(caps)
  end

  test "unknown provider returns error" do
    assert {:error, _} = HipcallTts.models(:unknown)
    assert {:error, _} = HipcallTts.voices(:unknown)
    assert {:error, _} = HipcallTts.languages(:unknown)
    assert {:error, _} = HipcallTts.capabilities(:unknown)
  end

  test "provider_opts are merged into provider params" do
    bypass = Bypass.open()

    original_url = Application.get_env(:hipcall_tts, :openai_endpoint_url)

    Application.put_env(
      :hipcall_tts,
      :openai_endpoint_url,
      "http://localhost:#{bypass.port}/v1/audio/speech"
    )

    on_exit(fn ->
      if original_url do
        Application.put_env(:hipcall_tts, :openai_endpoint_url, original_url)
      else
        Application.delete_env(:hipcall_tts, :openai_endpoint_url)
      end
    end)

    audio = "OK"

    Bypass.expect_once(bypass, "POST", "/v1/audio/speech", fn conn ->
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer provider-opts-key"]
      Plug.Conn.resp(conn, 200, audio)
    end)

    assert {:ok, ^audio} =
             HipcallTts.generate(
               provider: :openai,
               text: "Hello",
               voice: "nova",
               provider_opts: [api_key: "provider-opts-key"]
             )
  end

  test "validation errors are normalized" do
    assert {:error, err} = HipcallTts.generate(provider: :openai)
    assert err.code == :validation_error
    assert is_binary(err.message)
  end

  test "unknown provider in generate/1 fails validation" do
    assert {:error, err} = HipcallTts.generate(provider: :nope, text: "hi")
    assert err.code == :validation_error
    assert err.message =~ "invalid value for :provider option"
  end

  test "stream/1 delegates to provider (ElevenLabs stub)" do
    assert {:error, err} = HipcallTts.stream(provider: :elevenlabs, text: "hi")
    assert err.code == :not_implemented
    assert err.provider == :elevenlabs
  end

  test "generate/1 returns normalized error for non-list/map params" do
    assert {:error, err} = HipcallTts.generate(:bad)
    assert err.code == :error
    assert err.provider == nil
    assert err.message =~ "params must be a keyword list or map"
  end

  test "generate/1 returns normalized error for ElevenLabs not implemented" do
    assert {:error, err} = HipcallTts.generate(provider: :elevenlabs, text: "hi")
    assert err.code == :not_implemented
    assert err.provider == :elevenlabs
  end

  test "validate_params/1 supports map input" do
    assert {:ok, validated} = HipcallTts.validate_params(%{provider: :openai, text: "Hello"})
    assert validated[:provider] == :openai
  end

  test "generate/1 rescue path reraises exceptions (and uses safe_provider for map params)" do
    original_url = Application.get_env(:hipcall_tts, :openai_endpoint_url)
    Application.put_env(:hipcall_tts, :openai_endpoint_url, :bad_url)

    on_exit(fn ->
      if original_url do
        Application.put_env(:hipcall_tts, :openai_endpoint_url, original_url)
      else
        Application.delete_env(:hipcall_tts, :openai_endpoint_url)
      end
    end)

    assert_raise FunctionClauseError, fn ->
      HipcallTts.generate(%{provider: :openai, text: "Hello", voice: "nova", api_key: "x"})
    end
  end

  test "OpenAI provider reads api_key from env config when not provided in params" do
    bypass = Bypass.open()

    original_url = Application.get_env(:hipcall_tts, :openai_endpoint_url)
    original_providers = Application.get_env(:hipcall_tts, :providers)

    env_key = "HIPCALL_TTS_OPENAI_KEY_" <> Integer.to_string(System.unique_integer([:positive]))
    System.put_env(env_key, "env-key")

    Application.put_env(
      :hipcall_tts,
      :openai_endpoint_url,
      "http://localhost:#{bypass.port}/v1/audio/speech"
    )

    Application.put_env(
      :hipcall_tts,
      :providers,
      Keyword.merge(original_providers || [],
        openai: [
          api_key: {:system, env_key},
          api_organization: "org-test"
        ]
      )
    )

    on_exit(fn ->
      System.delete_env(env_key)

      if original_url do
        Application.put_env(:hipcall_tts, :openai_endpoint_url, original_url)
      else
        Application.delete_env(:hipcall_tts, :openai_endpoint_url)
      end

      if original_providers do
        Application.put_env(:hipcall_tts, :providers, original_providers)
      else
        Application.delete_env(:hipcall_tts, :providers)
      end
    end)

    audio = "OK"

    Bypass.expect_once(bypass, "POST", "/v1/audio/speech", fn conn ->
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer env-key"]
      assert Plug.Conn.get_req_header(conn, "openai-organization") == ["org-test"]
      Plug.Conn.resp(conn, 200, audio)
    end)

    assert {:ok, ^audio} =
             HipcallTts.generate(
               provider: :openai,
               text: "Hello",
               voice: "nova"
             )
  end
end
