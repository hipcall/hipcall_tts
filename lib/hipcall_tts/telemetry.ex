defmodule HipcallTts.Telemetry do
  @moduledoc """
  Telemetry helper module for HipcallTts.

  This module provides wrapper functions for emitting telemetry events
  throughout the HipcallTts library. All events follow the `[:hipcall_tts, ...]`
  naming convention.

  ## Events

  The following events are emitted:

  - `[:hipcall_tts, :generate, :start]` - Emitted when TTS generation starts
  - `[:hipcall_tts, :generate, :stop]` - Emitted when TTS generation completes
  - `[:hipcall_tts, :generate, :exception]` - Emitted when TTS generation fails with an exception
  - `[:hipcall_tts, :http, :request]` - Emitted for HTTP requests to provider APIs
  - `[:hipcall_tts, :retry, :attempt]` - Emitted when a retry attempt is made
  - `[:hipcall_tts, :text, :split]` - Emitted when text is split for processing

  ## Measurements

  Measurements typically include:
  - `:duration` - Duration in native time units (for `:stop` events)
  - `:system_time` - System time in native time units (for `:start` events)
  - `:count` - Count of items (for batch operations)

  ## Metadata

  Metadata typically includes:
  - `:provider` - The provider name (e.g., `:openai`, `:elevenlabs`)
  - `:text_length` - Length of the text being processed
  - `:voice` - Voice identifier
  - `:model` - Model identifier
  - `:attempt` - Retry attempt number
  - `:error` - Error information
  - `:status_code` - HTTP status code (for HTTP events)
  - `:chunks` - Number of text chunks (for split events)

  ## Example Event Handlers

      # Attach a handler to log all generate events
      defmodule MyApp.TelemetryHandlers do
        require Logger

        def attach_handlers do
          :telemetry.attach_many(
            "hipcall-tts-generate-handler",
            [
              [:hipcall_tts, :generate, :start],
              [:hipcall_tts, :generate, :stop],
              [:hipcall_tts, :generate, :exception]
            ],
            &handle_generate_event/4,
            nil
          )
        end

        defp handle_generate_event([:hipcall_tts, :generate, :start], measurements, metadata, _config) do
          Logger.info("TTS generation started", [
            provider: metadata.provider,
            text_length: metadata.text_length
          ])
        end

        defp handle_generate_event([:hipcall_tts, :generate, :stop], measurements, metadata, _config) do
          duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
          Logger.info("TTS generation completed", [
            provider: metadata.provider,
            duration_ms: duration_ms,
            text_length: metadata.text_length
          ])
        end

        defp handle_generate_event([:hipcall_tts, :generate, :exception], measurements, metadata, _config) do
          Logger.error("TTS generation failed", [
            provider: metadata.provider,
            kind: metadata.kind,
            error: metadata.error,
            stacktrace: metadata.stacktrace
          ])
        end
      end

      # Attach a handler to track HTTP requests
      :telemetry.attach(
        "hipcall-tts-http-handler",
        [:hipcall_tts, :http, :request],
        fn event, measurements, metadata, _config ->
          # Track HTTP requests in your monitoring system
          MyApp.Metrics.record_http_request(
            metadata.provider,
            measurements.status_code,
            measurements.duration
          )
        end,
        nil
      )

      # Attach a handler to track retry attempts
      :telemetry.attach(
        "hipcall-tts-retry-handler",
        [:hipcall_tts, :retry, :attempt],
        fn event, measurements, metadata, _config ->
          Logger.warn("Retry attempt made", [
            provider: metadata.provider,
            attempt: metadata.attempt,
            error: metadata.error
          ])
        end,
        nil
      )
  """

  # Event names as module attributes
  @generate_start_event [:hipcall_tts, :generate, :start]
  @generate_stop_event [:hipcall_tts, :generate, :stop]
  @generate_exception_event [:hipcall_tts, :generate, :exception]
  @http_request_event [:hipcall_tts, :http, :request]
  @retry_attempt_event [:hipcall_tts, :retry, :attempt]
  @text_split_event [:hipcall_tts, :text, :split]

  @doc """
  Emits a `[:hipcall_tts, :generate, :start]` event.

  This event is emitted when TTS generation begins.

  ## Parameters

  - `metadata` - A keyword list or map containing metadata about the generation
    - `:provider` - The provider name (required)
    - `:text_length` - Length of the text being processed (optional)
    - `:voice` - Voice identifier (optional)
    - `:model` - Model identifier (optional)

  ## Examples

      HipcallTts.Telemetry.generate_start(provider: :openai, text_length: 100, voice: "alloy")
  """
  def generate_start(metadata \\ []) do
    measurements = %{system_time: System.system_time()}
    :telemetry.execute(@generate_start_event, measurements, normalize_metadata(metadata))
  end

  @doc """
  Emits a `[:hipcall_tts, :generate, :stop]` event.

  This event is emitted when TTS generation completes successfully.

  ## Parameters

  - `duration` - Duration in native time units (from `System.monotonic_time()`)
  - `metadata` - A keyword list or map containing metadata about the generation
    - `:provider` - The provider name (required)
    - `:text_length` - Length of the text that was processed (optional)
    - `:voice` - Voice identifier used (optional)
    - `:model` - Model identifier used (optional)
    - `:audio_size` - Size of generated audio in bytes (optional)
    - `:format` - Audio format (optional)

  ## Examples

      start_time = System.monotonic_time()
      # ... perform generation ...
      duration = System.monotonic_time() - start_time
      HipcallTts.Telemetry.generate_stop(duration, provider: :openai, text_length: 100)
  """
  def generate_stop(duration, metadata \\ []) do
    measurements = %{duration: duration}
    :telemetry.execute(@generate_stop_event, measurements, normalize_metadata(metadata))
  end

  @doc """
  Emits a `[:hipcall_tts, :generate, :exception]` event.

  This event is emitted when TTS generation fails with an exception.

  ## Parameters

  - `kind` - Exception kind (`:error`, `:exit`, `:throw`)
  - `error` - The error/exception
  - `stacktrace` - The stacktrace
  - `metadata` - A keyword list or map containing metadata about the generation
    - `:provider` - The provider name (required)
    - `:text_length` - Length of the text that was processed (optional)
    - `:voice` - Voice identifier used (optional)
    - `:model` - Model identifier used (optional)

  ## Examples

      try do
        # ... generation code ...
      rescue
        error ->
          HipcallTts.Telemetry.generate_exception(:error, error, __STACKTRACE__,
            provider: :openai,
            text_length: 100
          )
          reraise error, __STACKTRACE__
      end
  """
  def generate_exception(kind, error, stacktrace, metadata \\ []) do
    measurements = %{system_time: System.system_time()}

    metadata =
      metadata
      |> normalize_metadata()
      |> Map.put(:kind, kind)
      |> Map.put(:error, error)
      |> Map.put(:stacktrace, stacktrace)

    :telemetry.execute(@generate_exception_event, measurements, metadata)
  end

  @doc """
  Emits a `[:hipcall_tts, :http, :request]` event.

  This event is emitted for HTTP requests to provider APIs.

  ## Parameters

  - `duration` - Request duration in native time units
  - `status_code` - HTTP status code
  - `metadata` - A keyword list or map containing metadata about the request
    - `:provider` - The provider name (required)
    - `:method` - HTTP method (e.g., `"GET"`, `"POST"`) (optional)
    - `:url` - Request URL (optional)
    - `:request_size` - Request body size in bytes (optional)
    - `:response_size` - Response body size in bytes (optional)

  ## Examples

      start_time = System.monotonic_time()
      # ... make HTTP request ...
      duration = System.monotonic_time() - start_time
      HipcallTts.Telemetry.http_request(duration, 200,
        provider: :openai,
        method: "POST",
        url: "https://api.openai.com/v1/audio/speech"
      )
  """
  def http_request(duration, status_code, metadata \\ []) do
    measurements = %{
      duration: duration,
      status_code: status_code
    }

    :telemetry.execute(@http_request_event, measurements, normalize_metadata(metadata))
  end

  @doc """
  Emits a `[:hipcall_tts, :retry, :attempt]` event.

  This event is emitted when a retry attempt is made after a failure.

  ## Parameters

  - `attempt` - The attempt number (1-based)
  - `metadata` - A keyword list or map containing metadata about the retry
    - `:provider` - The provider name (required)
    - `:error` - The error that triggered the retry (optional)
    - `:delay` - Delay before this retry attempt in milliseconds (optional)
    - `:max_attempts` - Maximum number of attempts (optional)

  ## Examples

      HipcallTts.Telemetry.retry_attempt(2,
        provider: :openai,
        error: "Connection timeout",
        delay: 1000,
        max_attempts: 3
      )
  """
  def retry_attempt(attempt, metadata \\ []) do
    measurements = %{system_time: System.system_time()}

    metadata =
      metadata
      |> normalize_metadata()
      |> Map.put(:attempt, attempt)

    :telemetry.execute(@retry_attempt_event, measurements, metadata)
  end

  @doc """
  Emits a `[:hipcall_tts, :text, :split]` event.

  This event is emitted when text is split into chunks for processing.

  ## Parameters

  - `chunks` - Number of chunks the text was split into
  - `metadata` - A keyword list or map containing metadata about the split
    - `:provider` - The provider name (required)
    - `:original_length` - Original text length (optional)
    - `:chunk_size` - Maximum chunk size (optional)
    - `:total_length` - Total length of all chunks (optional)

  ## Examples

      chunks = split_text(text, max_length: 5000)
      HipcallTts.Telemetry.text_split(length(chunks),
        provider: :openai,
        original_length: String.length(text),
        chunk_size: 5000
      )
  """
  def text_split(chunks, metadata \\ []) do
    measurements = %{
      chunks: chunks,
      system_time: System.system_time()
    }

    :telemetry.execute(@text_split_event, measurements, normalize_metadata(metadata))
  end

  # Helper function to normalize metadata (keyword list or map) to a map
  defp normalize_metadata(metadata) when is_list(metadata) do
    Map.new(metadata)
  end

  defp normalize_metadata(metadata) when is_map(metadata) do
    metadata
  end

  defp normalize_metadata(_), do: %{}
end
