defmodule HipcallTts.TelemetryTest do
  # Telemetry handlers are global; avoid concurrency issues.
  use ExUnit.Case, async: false

  alias HipcallTts.Telemetry

  def handle(event, measurements, metadata, _config) do
    send(self(), {:telemetry, event, measurements, metadata})
  end

  defp attach!(events) do
    id = "hipcall-tts-test-" <> Integer.to_string(System.unique_integer([:positive]))

    :telemetry.attach_many(
      id,
      events,
      &__MODULE__.handle/4,
      nil
    )

    on_exit(fn -> :telemetry.detach(id) end)
    :ok
  end

  test "generate telemetry helpers emit events" do
    attach!([
      [:hipcall_tts, :generate, :start],
      [:hipcall_tts, :generate, :stop],
      [:hipcall_tts, :generate, :error]
    ])

    Telemetry.generate_start(provider: :openai, text_length: 5)
    assert_receive {:telemetry, [:hipcall_tts, :generate, :start], _meas, meta}
    assert meta.provider == :openai

    Telemetry.generate_stop(123, provider: :openai, success: true)
    assert_receive {:telemetry, [:hipcall_tts, :generate, :stop], meas, meta}
    assert meas.duration == 123
    assert meta.success == true

    Telemetry.generate_error(456, %{code: :error, message: "nope"}, provider: :openai)
    assert_receive {:telemetry, [:hipcall_tts, :generate, :error], meas, meta}
    assert meas.duration == 456
    assert meta.provider == :openai
    assert meta.error[:code] == :error
  end

  test "http_request/retry_attempt/text_split emit events" do
    attach!([
      [:hipcall_tts, :http, :request],
      [:hipcall_tts, :retry, :attempt],
      [:hipcall_tts, :text, :split]
    ])

    Telemetry.http_request(100, 200, provider: :openai, method: "POST", url: "http://example")
    assert_receive {:telemetry, [:hipcall_tts, :http, :request], meas, meta}
    assert meas.status_code == 200
    assert meta.provider == :openai

    Telemetry.retry_attempt(2, provider: :openai, delay: 10)
    assert_receive {:telemetry, [:hipcall_tts, :retry, :attempt], _meas, meta}
    assert meta.attempt == 2

    Telemetry.text_split(3, provider: :openai, original_length: 100, chunk_size: 50)
    assert_receive {:telemetry, [:hipcall_tts, :text, :split], meas, meta}
    assert meas.chunks == 3
    assert meta.chunk_size == 50
  end

  test "generate_exception emits exception event and normalize_metadata handles maps" do
    attach!([[:hipcall_tts, :generate, :exception], [:hipcall_tts, :generate, :start]])

    Telemetry.generate_start(%{provider: :openai, text_length: 1})
    assert_receive {:telemetry, [:hipcall_tts, :generate, :start], _meas, meta}
    assert meta.provider == :openai

    Telemetry.generate_exception(:error, %RuntimeError{message: "boom"}, [], provider: :openai)
    assert_receive {:telemetry, [:hipcall_tts, :generate, :exception], _meas, meta}
    assert meta.provider == :openai
    assert meta.kind == :error
    assert match?(%RuntimeError{}, meta.error)
  end

  test "normalize_metadata fallback works for non-map/non-keyword inputs" do
    attach!([
      [:hipcall_tts, :generate, :start],
      [:hipcall_tts, :generate, :stop],
      [:hipcall_tts, :generate, :error]
    ])

    # start with invalid metadata input -> should become %{}
    Telemetry.generate_start(123)
    assert_receive {:telemetry, [:hipcall_tts, :generate, :start], _meas, meta}
    assert meta == %{}

    # stop with invalid metadata input -> should become %{}
    Telemetry.generate_stop(1, 456)
    assert_receive {:telemetry, [:hipcall_tts, :generate, :stop], _meas, meta}
    assert meta == %{}

    # error with map metadata input
    Telemetry.generate_error(2, %{code: :error, message: "nope"}, %{provider: :openai})
    assert_receive {:telemetry, [:hipcall_tts, :generate, :error], _meas, meta}
    assert meta.provider == :openai
  end
end
