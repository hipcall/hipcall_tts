defmodule HipcallTts.Providers.PollyTest do
  # Uses Application env overrides for endpoint URL; must not run concurrently.
  use ExUnit.Case, async: false

  alias HipcallTts.Providers.Polly

  setup do
    bypass = Bypass.open()

    original_url = Application.get_env(:hipcall_tts, :polly_endpoint_url)

    Application.put_env(
      :hipcall_tts,
      :polly_endpoint_url,
      "http://localhost:#{bypass.port}/v1/speech"
    )

    on_exit(fn ->
      if original_url do
        Application.put_env(:hipcall_tts, :polly_endpoint_url, original_url)
      else
        Application.delete_env(:hipcall_tts, :polly_endpoint_url)
      end
    end)

    {:ok, bypass: bypass}
  end

  test "introspection functions return data" do
    assert is_list(Polly.models())
    assert is_list(Polly.voices())
    assert is_list(Polly.languages())
    assert is_map(Polly.capabilities())
    assert Polly.capabilities().streaming == false
  end

  test "validate_params/1 rejects empty text" do
    assert {:error, _} = Polly.validate_params(text: "")
  end

  test "generate/1 signs request and returns audio binary", %{bypass: bypass} do
    audio = "POLLYAUDIO"

    Bypass.expect_once(bypass, "POST", "/v1/speech", fn conn ->
      # headers should include SigV4
      [auth] = Plug.Conn.get_req_header(conn, "authorization")
      assert String.starts_with?(auth, "AWS4-HMAC-SHA256 ")

      assert Plug.Conn.get_req_header(conn, "x-amz-date") != []
      assert Plug.Conn.get_req_header(conn, "content-type") != []

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)

      assert decoded["Text"] == "Hello"
      assert decoded["VoiceId"] == "Joanna"
      assert decoded["OutputFormat"] == "mp3"

      Plug.Conn.resp(conn, 200, audio)
    end)

    params = [
      text: "Hello",
      voice: "Joanna",
      format: "mp3",
      model: "standard",
      access_key_id: "AKIDEXAMPLE",
      secret_access_key: "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY",
      region: "us-east-1"
    ]

    assert {:ok, ^audio} = Polly.generate(params)
  end

  test "generate/1 supports ssml, sample_rate and session_token", %{bypass: bypass} do
    audio = "POLLYAUDIO"

    Bypass.expect_once(bypass, "POST", "/v1/speech", fn conn ->
      assert Plug.Conn.get_req_header(conn, "x-amz-security-token") == ["token123"]

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)

      assert decoded["TextType"] == "ssml"
      assert decoded["SampleRate"] == "16000"

      Plug.Conn.resp(conn, 200, audio)
    end)

    params = [
      text: "<speak>Hello</speak>",
      voice: "Joanna",
      format: "mp3",
      model: "standard",
      sample_rate: 16_000,
      access_key_id: "AKIDEXAMPLE",
      secret_access_key: "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY",
      region: "us-east-1",
      session_token: "token123"
    ]

    assert {:ok, ^audio} = Polly.generate(params)
  end

  test "validate_params/1 rejects invalid fields" do
    assert {:error, _} = Polly.validate_params(text: String.duplicate("a", 4000))
    assert {:error, _} = Polly.validate_params(text: "hi", voice: "NOPE")
    assert {:error, _} = Polly.validate_params(text: "hi", model: "NOPE")
    assert {:error, _} = Polly.validate_params(text: "hi", format: "wav")
  end

  test "generate/1 works with endpoint query string and default region", %{bypass: bypass} do
    # Override endpoint_url to include a query string (exercises canonical query handling).
    original_url = Application.get_env(:hipcall_tts, :polly_endpoint_url)

    Application.put_env(
      :hipcall_tts,
      :polly_endpoint_url,
      "http://localhost:#{bypass.port}/v1/speech?x=1&y=2"
    )

    on_exit(fn ->
      if original_url do
        Application.put_env(:hipcall_tts, :polly_endpoint_url, original_url)
      else
        Application.delete_env(:hipcall_tts, :polly_endpoint_url)
      end
    end)

    audio = "POLLYAUDIO"

    Bypass.expect_once(bypass, "POST", "/v1/speech", fn conn ->
      Plug.Conn.resp(conn, 200, audio)
    end)

    # No region provided -> provider uses default region internally for signing.
    params = [
      text: "Hello",
      voice: "Joanna",
      format: "mp3",
      access_key_id: "AKIDEXAMPLE",
      secret_access_key: "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY"
    ]

    assert {:ok, ^audio} = Polly.generate(params)
  end
end
