defmodule HipcallTts.Provider do
  @moduledoc """
  Behaviour for Text-to-Speech (TTS) providers.

  This behaviour defines the contract that all TTS providers must implement.
  It includes callbacks for generating speech, streaming audio, validating parameters,
  and querying provider capabilities.

  ## Types

  - `params` - Parameters for TTS generation (text, voice, model, etc.)
  - `result` - The generated audio data
  - `error` - Error information when generation fails
  - `model` - TTS model information
  - `voice` - Voice information (name, gender, language, etc.)
  - `language` - Language information
  - `capabilities` - Provider capabilities (streaming, formats, etc.)

  ## Example

      defmodule MyProvider do
        @behaviour HipcallTts.Provider

        @impl HipcallTts.Provider
        def generate(params) do
          # Implementation
        end

        # ... other callbacks
      end
  """

  @type params :: keyword() | map()
  @type result :: binary() | %{audio: binary(), format: String.t(), sample_rate: integer()}
  @type error :: %{message: String.t(), code: atom()} | String.t()
  @type model :: %{
          id: String.t(),
          name: String.t(),
          description: String.t() | nil,
          languages: [String.t()] | nil
        }
  @type voice :: %{
          id: String.t(),
          name: String.t(),
          gender: :male | :female | :neutral | nil,
          language: String.t(),
          locale: String.t() | nil
        }
  @type language :: %{
          code: String.t(),
          name: String.t(),
          locale: String.t() | nil
        }
  @type capabilities :: %{
          streaming: boolean(),
          formats: [String.t()],
          sample_rates: [integer()],
          max_text_length: integer() | :infinity
        }

  @doc """
  Generates speech audio from the given parameters.

  Returns `{:ok, result}` on success or `{:error, error}` on failure.

  ## Parameters

  The `params` should include at minimum:
  - `:text` or `"text"` - The text to convert to speech
  - `:voice` or `"voice"` - The voice identifier to use
  - `:model` or `"model"` - The model identifier to use (optional)

  ## Examples

      {:ok, audio_data} = Provider.generate(text: "Hello", voice: "en-US-Standard-A")
      {:error, "Invalid voice"} = Provider.generate(text: "Hello", voice: "invalid")
  """
  @callback generate(params) :: {:ok, result} | {:error, error}

  @doc """
  Streams speech audio generation from the given parameters.

  Returns `{:ok, Enumerable.t()}` that yields audio chunks, or `{:error, error}` on failure.

  This is useful for long texts or real-time applications where you want to start
  playing audio before the entire generation is complete.

  ## Examples

      {:ok, stream} = Provider.stream(text: "Long text...", voice: "en-US-Standard-A")
      Enum.each(stream, fn chunk -> play_audio(chunk) end)
  """
  @callback stream(params) :: {:ok, Enumerable.t()} | {:error, error}

  @doc """
  Validates the given parameters before attempting generation.

  Returns `:ok` if parameters are valid, or `{:error, String.t()}` with a description
  of the validation error.

  This allows clients to check parameters before making potentially expensive API calls.

  ## Examples

      :ok = Provider.validate_params(text: "Hello", voice: "en-US-Standard-A")
      {:error, "Text cannot be empty"} = Provider.validate_params(text: "", voice: "en-US-Standard-A")
  """
  @callback validate_params(params) :: :ok | {:error, String.t()}

  @doc """
  Returns a list of available models for this provider.

  ## Examples

      models = Provider.models()
      # => [%{id: "model-1", name: "Standard Model", ...}, ...]
  """
  @callback models() :: [model]

  @doc """
  Returns a list of available voices for this provider.

  ## Examples

      voices = Provider.voices()
      # => [%{id: "voice-1", name: "Alice", gender: :female, ...}, ...]
  """
  @callback voices() :: [voice]

  @doc """
  Returns a list of supported languages for this provider.

  ## Examples

      languages = Provider.languages()
      # => [%{code: "en", name: "English", ...}, ...]
  """
  @callback languages() :: [language]

  @doc """
  Returns the capabilities of this provider.

  This includes information about supported features like streaming,
  audio formats, sample rates, and text length limits.

  ## Examples

      caps = Provider.capabilities()
      # => %{streaming: true, formats: ["mp3", "wav"], ...}
  """
  @callback capabilities() :: capabilities
end
