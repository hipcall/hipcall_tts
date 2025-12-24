defmodule HipcallTts.Schema do
  @moduledoc """
  Defines the schema for HipcallTts parameters using NimbleOptions.

  This module provides a comprehensive schema for validating TTS generation
  parameters, including nested retry options.

  ## Usage

      opts = [
        provider: :openai,
        text: "Hello, world!",
        voice: "en-US-Standard-A",
        retry_opts: [max_attempts: 3, initial_delay: 1000]
      ]

      case NimbleOptions.validate(opts, HipcallTts.Schema.generate_schema()) do
        {:ok, validated_opts} ->
          # Use validated_opts
        {:error, error} ->
          # Handle validation error
      end
  """

  @doc """
  Generates the NimbleOptions schema for TTS generation parameters.

  ## Required Parameters

  - `:provider` - The TTS provider to use (`:openai`, `:elevenlabs`, or `:polly`)
  - `:text` - The text to convert to speech

  ## Optional Parameters

  - `:voice` - The voice identifier to use for speech synthesis
  - `:model` - The model identifier to use (provider-specific)
  - `:format` - Audio format (e.g., "mp3", "wav", "ogg")
  - `:sample_rate` - Sample rate in Hz (e.g., 22050, 44100)
  - `:speed` - Speech speed/rate (float, typically 0.25 to 4.0)
  - `:pitch` - Voice pitch adjustment (float, typically -20.0 to 20.0)
  - `:language` - Language code (e.g., "en-US", "en-GB")
  - `:retry_opts` - Nested keyword list of retry configuration options

  ## Retry Options

  The `:retry_opts` parameter accepts a nested keyword list with:
  - `:max_attempts` - Maximum number of retry attempts (default: 3)
  - `:initial_delay` - Initial delay before first retry in milliseconds (default: 1000)
  - `:max_delay` - Maximum delay between retries in milliseconds (default: 10000)
  - `:backoff_factor` - Exponential backoff multiplier (default: 2.0)
  - `:retryable_errors` - List of error codes/atoms that should trigger retries (default: [])

  ## Examples

      # Minimal valid params
      opts = [provider: :openai, text: "Hello"]

      # Full params with retry options
      opts = [
        provider: :openai,
        text: "Hello, world!",
        voice: "en-US-Standard-A",
        model: "tts-1",
        format: "mp3",
        sample_rate: 44100,
        speed: 1.0,
        pitch: 0.0,
        language: "en-US",
        retry_opts: [
          max_attempts: 5,
          initial_delay: 500,
          max_delay: 5000,
          backoff_factor: 1.5,
          retryable_errors: [:timeout, :network_error]
        ]
      ]
  """
  def generate_schema do
    [
      provider: [
        type: {:in, [:openai, :elevenlabs, :polly]},
        required: true,
        doc: """
        TTS provider to use.

        Supported providers:
        - `:openai` - OpenAI TTS API
        - `:elevenlabs` - ElevenLabs TTS API
        - `:polly` - AWS Polly TTS service
        """
      ],
      text: [
        type: :string,
        required: true,
        doc: """
        Text to convert to speech.

        The text should be non-empty and within the provider's maximum length limits.
        """
      ],
      api_key: [
        type: :string,
        required: false,
        doc: """
        Provider API key override for this request.

        If omitted, the provider will read its configured key from application env
        (for example `OPENAI_API_KEY` for OpenAI).
        """
      ],
      api_organization: [
        type: :string,
        required: false,
        doc: """
        Provider organization/account identifier override for this request (provider-specific).

        Example (OpenAI): `"org_..."` for the `OpenAI-Organization` header.
        """
      ],
      access_key_id: [
        type: :string,
        required: false,
        doc: """
        AWS Access Key ID override for this request (Polly).

        If omitted, reads from application env config (e.g. `AWS_ACCESS_KEY_ID`).
        """
      ],
      secret_access_key: [
        type: :string,
        required: false,
        doc: """
        AWS Secret Access Key override for this request (Polly).

        If omitted, reads from application env config (e.g. `AWS_SECRET_ACCESS_KEY`).
        """
      ],
      session_token: [
        type: :string,
        required: false,
        doc: """
        AWS Session Token override for this request (Polly), for temporary credentials.
        """
      ],
      region: [
        type: :string,
        required: false,
        doc: """
        AWS region override for this request (Polly), e.g. `"us-east-1"`.
        """
      ],
      provider_opts: [
        type: :keyword_list,
        required: false,
        default: [],
        doc: """
        Provider-specific options (recommended going forward).

        This is a flexible escape-hatch to avoid growing the top-level schema forever.
        Options placed here are merged into the provider params before calling the provider.

        Example:

            provider_opts: [api_key: "sk-...", region: "us-east-1"]
        """
      ],
      voice: [
        type: :string,
        required: false,
        doc: """
        Voice identifier to use for speech synthesis.

        This is provider-specific. Examples:
        - OpenAI: "alloy", "echo", "fable", "onyx", "nova", "shimmer"
        - ElevenLabs: Voice ID string
        - AWS Polly: Voice name like "Joanna", "Matthew", etc.
        """
      ],
      model: [
        type: :string,
        required: false,
        doc: """
        Model identifier to use for TTS generation.

        This is provider-specific and optional. If not provided, the provider
        will use its default model.
        """
      ],
      format: [
        type: {:in, ["mp3", "wav", "ogg_vorbis", "pcm", "opus", "aac", "flac"]},
        required: false,
        default: "mp3",
        doc: """
        Audio format for the generated speech.

        Supported formats: "mp3", "wav", "ogg_vorbis", "pcm", "opus", "aac", "flac"
        Default: "mp3"
        """
      ],
      sample_rate: [
        type: :pos_integer,
        required: false,
        default: 22050,
        doc: """
        Sample rate in Hz for the generated audio.

        Common values: 16000, 22050, 44100, 48000
        Default: 22050
        """
      ],
      speed: [
        type: :float,
        required: false,
        default: 1.0,
        doc: """
        Speech speed/rate multiplier.

        Typical range: 0.25 to 4.0
        - 0.5 = half speed
        - 1.0 = normal speed (default)
        - 2.0 = double speed
        """
      ],
      pitch: [
        type: :float,
        required: false,
        default: 0.0,
        doc: """
        Voice pitch adjustment in semitones.

        Typical range: -20.0 to 20.0
        - Negative values = lower pitch
        - 0.0 = no change (default)
        - Positive values = higher pitch
        """
      ],
      language: [
        type: :string,
        required: false,
        doc: """
        Language code for the text.

        Examples: "en-US", "en-GB", "es-ES", "fr-FR"
        If not provided, the provider may auto-detect or use a default.
        """
      ],
      retry_opts: [
        type: :keyword_list,
        required: false,
        default: [],
        keys: retry_opts_schema(),
        doc: """
        Retry configuration options for handling transient failures.

        See `retry_opts_schema/0` for available options.
        """
      ]
    ]
  end

  @spec retry_opts_schema() :: [
          {:backoff_factor, [{any(), any()}, ...]}
          | {:initial_delay, [{any(), any()}, ...]}
          | {:max_attempts, [{any(), any()}, ...]}
          | {:max_delay, [{any(), any()}, ...]}
          | {:retryable_errors, [{any(), any()}, ...]},
          ...
        ]
  @doc """
  Generates the schema for nested retry options.

  This is used internally by `generate_schema/0` but can also be used
  independently to validate retry options separately.

  ## Options

  - `:max_attempts` - Maximum number of retry attempts (default: 3)
  - `:initial_delay` - Initial delay before first retry in milliseconds (default: 1000)
  - `:max_delay` - Maximum delay between retries in milliseconds (default: 10000)
  - `:backoff_factor` - Exponential backoff multiplier (default: 2.0)
  - `:retryable_errors` - List of error codes/atoms that should trigger retries (default: [])

  ## Examples

      retry_opts = [
        max_attempts: 5,
        initial_delay: 500,
        max_delay: 5000,
        backoff_factor: 1.5,
        retryable_errors: [:timeout, :network_error]
      ]

      case NimbleOptions.validate(retry_opts, HipcallTts.Schema.retry_opts_schema()) do
        {:ok, validated} -> # Use validated options
        {:error, error} -> # Handle error
      end
  """
  def retry_opts_schema do
    [
      max_attempts: [
        type: :non_neg_integer,
        required: false,
        default: 3,
        doc: """
        Maximum number of retry attempts.

        Must be a non-negative integer.

        - `0` means "no retries" (only the initial attempt).
        - Total number of attempts will be `max_attempts + 1` (initial attempt + retries).
        Default: 3
        """
      ],
      initial_delay: [
        type: :non_neg_integer,
        required: false,
        default: 1000,
        doc: """
        Initial delay before the first retry in milliseconds.

        Must be a non-negative integer.
        Default: 1000 (1 second)
        """
      ],
      max_delay: [
        type: :non_neg_integer,
        required: false,
        default: 10000,
        doc: """
        Maximum delay between retries in milliseconds.

        The actual delay will be capped at this value even if the exponential
        backoff calculation exceeds it.
        Default: 10000 (10 seconds)
        """
      ],
      backoff_factor: [
        type: {:custom, __MODULE__, :validate_positive_float, []},
        required: false,
        default: 2.0,
        doc: """
        Exponential backoff multiplier.

        Each retry delay is calculated as: initial_delay * (backoff_factor ^ attempt_number)
        Must be a positive float.
        Default: 2.0
        """
      ],
      retryable_errors: [
        type: {:list, :atom},
        required: false,
        default: [],
        doc: """
        List of error codes/atoms that should trigger retries.

        If empty (default), all errors will be retried up to max_attempts.
        If specified, only errors matching these codes will be retried.
        Example: [:timeout, :network_error, :rate_limit]
        Default: []
        """
      ]
    ]
  end

  @doc false
  def validate_positive_float(value) when is_float(value) and value > 0, do: {:ok, value}

  def validate_positive_float(value) when is_float(value),
    do: {:error, "must be a positive float, got: #{value}"}

  def validate_positive_float(value), do: {:error, "must be a float, got: #{inspect(value)}"}
end
