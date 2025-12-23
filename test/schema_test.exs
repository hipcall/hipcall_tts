defmodule HipcallTts.SchemaTest do
  use ExUnit.Case, async: true

  alias HipcallTts.Schema

  describe "generate_schema/0 - Valid params pass validation" do
    test "minimal valid params" do
      opts = [provider: :openai, text: "Hello, world!"]

      assert {:ok, validated} = NimbleOptions.validate(opts, Schema.generate_schema())
      assert Keyword.get(validated, :provider) == :openai
      assert Keyword.get(validated, :text) == "Hello, world!"
    end

    test "all valid providers" do
      providers = [:openai, :elevenlabs, :polly]

      for provider <- providers do
        opts = [provider: provider, text: "Test"]

        assert {:ok, validated} = NimbleOptions.validate(opts, Schema.generate_schema())
        assert Keyword.get(validated, :provider) == provider
      end
    end

    test "full valid params with all optional fields" do
      opts = [
        provider: :openai,
        text: "Hello, world!",
        voice: "en-US-Standard-A",
        model: "tts-1",
        format: "mp3",
        sample_rate: 44100,
        speed: 1.5,
        pitch: 2.0,
        language: "en-US"
      ]

      assert {:ok, validated} = NimbleOptions.validate(opts, Schema.generate_schema())
      assert Keyword.get(validated, :provider) == :openai
      assert Keyword.get(validated, :text) == "Hello, world!"
      assert Keyword.get(validated, :voice) == "en-US-Standard-A"
      assert Keyword.get(validated, :model) == "tts-1"
      assert Keyword.get(validated, :format) == "mp3"
      assert Keyword.get(validated, :sample_rate) == 44100
      assert Keyword.get(validated, :speed) == 1.5
      assert Keyword.get(validated, :pitch) == 2.0
      assert Keyword.get(validated, :language) == "en-US"
    end

    test "valid params with default values applied" do
      opts = [provider: :openai, text: "Hello"]

      assert {:ok, validated} = NimbleOptions.validate(opts, Schema.generate_schema())
      assert Keyword.get(validated, :format) == "mp3"
      assert Keyword.get(validated, :sample_rate) == 22050
      assert Keyword.get(validated, :speed) == 1.0
      assert Keyword.get(validated, :pitch) == 0.0
    end

    test "valid params with valid format options" do
      formats = ["mp3", "wav"]

      for format <- formats do
        opts = [provider: :openai, text: "Test", format: format]

        assert {:ok, validated} = NimbleOptions.validate(opts, Schema.generate_schema())
        assert Keyword.get(validated, :format) == format
      end
    end
  end

  describe "generate_schema/0 - Missing required params fail" do
    test "missing provider fails" do
      opts = [text: "Hello, world!"]

      assert {:error, error} = NimbleOptions.validate(opts, Schema.generate_schema())
      assert %NimbleOptions.ValidationError{} = error
      assert error.message =~ "required :provider"
    end

    test "missing text fails" do
      opts = [provider: :openai]

      assert {:error, error} = NimbleOptions.validate(opts, Schema.generate_schema())
      assert %NimbleOptions.ValidationError{} = error
      assert error.message =~ "required :text"
    end

    test "missing both required params fails" do
      opts = []

      assert {:error, error} = NimbleOptions.validate(opts, Schema.generate_schema())
      assert %NimbleOptions.ValidationError{} = error
      assert error.message =~ "required"
    end

    test "nil provider fails" do
      opts = [provider: nil, text: "Hello"]

      assert {:error, error} = NimbleOptions.validate(opts, Schema.generate_schema())
      assert %NimbleOptions.ValidationError{} = error
    end

    test "nil text fails" do
      opts = [provider: :openai, text: nil]

      assert {:error, error} = NimbleOptions.validate(opts, Schema.generate_schema())
      assert %NimbleOptions.ValidationError{} = error
    end
  end

  describe "generate_schema/0 - Invalid provider fails" do
    test "invalid provider atom fails" do
      opts = [provider: :invalid_provider, text: "Hello"]

      assert {:error, error} = NimbleOptions.validate(opts, Schema.generate_schema())
      assert %NimbleOptions.ValidationError{} = error
      assert error.message =~ "invalid value for :provider option"
    end

    test "provider as string fails" do
      opts = [provider: "openai", text: "Hello"]

      assert {:error, error} = NimbleOptions.validate(opts, Schema.generate_schema())
      assert %NimbleOptions.ValidationError{} = error
    end

    test "provider as integer fails" do
      opts = [provider: 123, text: "Hello"]

      assert {:error, error} = NimbleOptions.validate(opts, Schema.generate_schema())
      assert %NimbleOptions.ValidationError{} = error
    end
  end

  describe "generate_schema/0 - Nested retry_opts validated" do
    test "valid retry_opts with all fields" do
      opts = [
        provider: :openai,
        text: "Hello",
        retry_opts: [
          max_attempts: 5,
          initial_delay: 500,
          max_delay: 5000,
          backoff_factor: 1.5,
          retryable_errors: [:timeout, :network_error]
        ]
      ]

      assert {:ok, validated} = NimbleOptions.validate(opts, Schema.generate_schema())
      retry_opts = Keyword.get(validated, :retry_opts)
      assert Keyword.get(retry_opts, :max_attempts) == 5
      assert Keyword.get(retry_opts, :initial_delay) == 500
      assert Keyword.get(retry_opts, :max_delay) == 5000
      assert Keyword.get(retry_opts, :backoff_factor) == 1.5
      assert Keyword.get(retry_opts, :retryable_errors) == [:timeout, :network_error]
    end

    test "retry_opts with default values" do
      opts = [
        provider: :openai,
        text: "Hello",
        retry_opts: []
      ]

      assert {:ok, validated} = NimbleOptions.validate(opts, Schema.generate_schema())
      retry_opts = Keyword.get(validated, :retry_opts)
      assert Keyword.get(retry_opts, :max_attempts) == 3
      assert Keyword.get(retry_opts, :initial_delay) == 1000
      assert Keyword.get(retry_opts, :max_delay) == 10000
      assert Keyword.get(retry_opts, :backoff_factor) == 2.0
      assert Keyword.get(retry_opts, :retryable_errors) == []
    end

    test "retry_opts with partial fields uses defaults for missing ones" do
      opts = [
        provider: :openai,
        text: "Hello",
        retry_opts: [
          max_attempts: 10
        ]
      ]

      assert {:ok, validated} = NimbleOptions.validate(opts, Schema.generate_schema())
      retry_opts = Keyword.get(validated, :retry_opts)
      assert Keyword.get(retry_opts, :max_attempts) == 10
      assert Keyword.get(retry_opts, :initial_delay) == 1000
      assert Keyword.get(retry_opts, :max_delay) == 10000
      assert Keyword.get(retry_opts, :backoff_factor) == 2.0
    end

    test "invalid max_attempts in retry_opts fails" do
      opts = [
        provider: :openai,
        text: "Hello",
        retry_opts: [
          max_attempts: 0
        ]
      ]

      assert {:error, error} = NimbleOptions.validate(opts, Schema.generate_schema())
      assert %NimbleOptions.ValidationError{} = error
      assert error.message =~ "invalid value for :max_attempts option"
    end

    test "negative max_attempts in retry_opts fails" do
      opts = [
        provider: :openai,
        text: "Hello",
        retry_opts: [
          max_attempts: -1
        ]
      ]

      assert {:error, error} = NimbleOptions.validate(opts, Schema.generate_schema())
      assert %NimbleOptions.ValidationError{} = error
    end

    test "invalid initial_delay in retry_opts fails" do
      opts = [
        provider: :openai,
        text: "Hello",
        retry_opts: [
          initial_delay: -100
        ]
      ]

      assert {:error, error} = NimbleOptions.validate(opts, Schema.generate_schema())
      assert %NimbleOptions.ValidationError{} = error
      assert error.message =~ "invalid value for :initial_delay option"
    end

    test "invalid max_delay in retry_opts fails" do
      opts = [
        provider: :openai,
        text: "Hello",
        retry_opts: [
          max_delay: -5000
        ]
      ]

      assert {:error, error} = NimbleOptions.validate(opts, Schema.generate_schema())
      assert %NimbleOptions.ValidationError{} = error
    end

    test "invalid backoff_factor in retry_opts fails" do
      opts = [
        provider: :openai,
        text: "Hello",
        retry_opts: [
          backoff_factor: -1.0
        ]
      ]

      assert {:error, error} = NimbleOptions.validate(opts, Schema.generate_schema())
      assert %NimbleOptions.ValidationError{} = error
    end

    test "zero backoff_factor in retry_opts fails" do
      opts = [
        provider: :openai,
        text: "Hello",
        retry_opts: [
          backoff_factor: 0.0
        ]
      ]

      assert {:error, error} = NimbleOptions.validate(opts, Schema.generate_schema())
      assert %NimbleOptions.ValidationError{} = error
    end

    test "invalid retryable_errors type in retry_opts fails" do
      opts = [
        provider: :openai,
        text: "Hello",
        retry_opts: [
          retryable_errors: "not a list"
        ]
      ]

      assert {:error, error} = NimbleOptions.validate(opts, Schema.generate_schema())
      assert %NimbleOptions.ValidationError{} = error
    end

    test "retryable_errors with non-atom elements fails" do
      opts = [
        provider: :openai,
        text: "Hello",
        retry_opts: [
          retryable_errors: [:timeout, "network_error"]
        ]
      ]

      assert {:error, error} = NimbleOptions.validate(opts, Schema.generate_schema())
      assert %NimbleOptions.ValidationError{} = error
    end

    test "valid retryable_errors with empty list" do
      opts = [
        provider: :openai,
        text: "Hello",
        retry_opts: [
          retryable_errors: []
        ]
      ]

      assert {:ok, validated} = NimbleOptions.validate(opts, Schema.generate_schema())
      retry_opts = Keyword.get(validated, :retry_opts)
      assert Keyword.get(retry_opts, :retryable_errors) == []
    end

    test "retry_opts with non-keyword-list fails" do
      opts = [
        provider: :openai,
        text: "Hello",
        retry_opts: %{max_attempts: 3}
      ]

      assert {:error, error} = NimbleOptions.validate(opts, Schema.generate_schema())
      assert %NimbleOptions.ValidationError{} = error
    end
  end

  describe "generate_schema/0 - Additional validation tests" do
    test "invalid format fails" do
      opts = [provider: :openai, text: "Hello", format: "invalid_format"]

      assert {:error, error} = NimbleOptions.validate(opts, Schema.generate_schema())
      assert %NimbleOptions.ValidationError{} = error
      assert error.message =~ "invalid value for :format option"
    end

    test "invalid sample_rate type fails" do
      opts = [provider: :openai, text: "Hello", sample_rate: "not_a_number"]

      assert {:error, error} = NimbleOptions.validate(opts, Schema.generate_schema())
      assert %NimbleOptions.ValidationError{} = error
    end

    test "zero or negative sample_rate fails" do
      opts = [provider: :openai, text: "Hello", sample_rate: 0]

      assert {:error, error} = NimbleOptions.validate(opts, Schema.generate_schema())
      assert %NimbleOptions.ValidationError{} = error
    end

    test "invalid speed type fails" do
      opts = [provider: :openai, text: "Hello", speed: "not_a_float"]

      assert {:error, error} = NimbleOptions.validate(opts, Schema.generate_schema())
      assert %NimbleOptions.ValidationError{} = error
    end

    test "invalid pitch type fails" do
      opts = [provider: :openai, text: "Hello", pitch: "not_a_float"]

      assert {:error, error} = NimbleOptions.validate(opts, Schema.generate_schema())
      assert %NimbleOptions.ValidationError{} = error
    end

    test "text as non-string fails" do
      opts = [provider: :openai, text: 123]

      assert {:error, error} = NimbleOptions.validate(opts, Schema.generate_schema())
      assert %NimbleOptions.ValidationError{} = error
    end
  end

  describe "retry_opts_schema/0" do
    test "can validate retry_opts independently" do
      retry_opts = [
        max_attempts: 5,
        initial_delay: 500,
        max_delay: 5000,
        backoff_factor: 1.5,
        retryable_errors: [:timeout]
      ]

      assert {:ok, validated} = NimbleOptions.validate(retry_opts, Schema.retry_opts_schema())
      assert Keyword.get(validated, :max_attempts) == 5
      assert Keyword.get(validated, :initial_delay) == 500
      assert Keyword.get(validated, :max_delay) == 5000
      assert Keyword.get(validated, :backoff_factor) == 1.5
      assert Keyword.get(validated, :retryable_errors) == [:timeout]
    end

    test "retry_opts_schema applies defaults" do
      retry_opts = []

      assert {:ok, validated} = NimbleOptions.validate(retry_opts, Schema.retry_opts_schema())
      assert Keyword.get(validated, :max_attempts) == 3
      assert Keyword.get(validated, :initial_delay) == 1000
      assert Keyword.get(validated, :max_delay) == 10000
      assert Keyword.get(validated, :backoff_factor) == 2.0
      assert Keyword.get(validated, :retryable_errors) == []
    end
  end

  @doc false
  def validate_positive_float(value) when is_float(value) and value > 0, do: {:ok, value}

  def validate_positive_float(value) when is_float(value),
    do: {:error, "must be a positive float, got: #{value}"}

  def validate_positive_float(value), do: {:error, "must be a float, got: #{inspect(value)}"}
end
