defmodule HipcallTts.Providers.Soniox do
  @behaviour HipcallTts.Provider

  @moduledoc """
  Soniox Text-to-Speech provider.

  Implements `HipcallTts.Provider` using the Soniox TTS REST endpoint.

  Soniox uses a single unified model, so every voice works with every supported
  language. The `:language` parameter is required by the Soniox API; this provider
  normalizes locale-style values (`"tr-TR"`) to the bare ISO code (`"tr"`) that
  Soniox expects, and falls back to the configured `:default_language`.

  Note: Soniox supports WebSocket streaming, but `stream/1` is not implemented yet
  in this package, so `capabilities().streaming` is currently `false`.
  """

  alias HipcallTts.Config
  alias HipcallTts.Telemetry

  @default_endpoint_url "https://tts-rt.soniox.com/tts"

  @models [
    %{
      id: "tts-rt-v2",
      name: "TTS RT v2",
      description: "Real-time multilingual model, 60+ languages, expressive output",
      languages: nil
    }
  ]

  @model_ids Enum.map(@models, & &1.id)

  @supported_languages [
    "af",
    "ar",
    "az",
    "be",
    "bg",
    "bn",
    "bs",
    "ca",
    "cs",
    "cy",
    "da",
    "de",
    "el",
    "en",
    "es",
    "et",
    "eu",
    "fa",
    "fi",
    "fr",
    "gl",
    "gu",
    "he",
    "hi",
    "hr",
    "hu",
    "id",
    "is",
    "it",
    "ja",
    "kk",
    "kn",
    "ko",
    "lt",
    "lv",
    "mk",
    "ml",
    "mr",
    "ms",
    "nl",
    "no",
    "pa",
    "pl",
    "pt",
    "ro",
    "ru",
    "sk",
    "sl",
    "sq",
    "sr",
    "su",
    "sv",
    "sw",
    "ta",
    "te",
    "th",
    "tl",
    "tr",
    "uk",
    "ur",
    "uz",
    "vi",
    "zh"
  ]

  @languages [
    %{code: "af", name: "Afrikaans", locale: nil},
    %{code: "ar", name: "Arabic", locale: nil},
    %{code: "az", name: "Azerbaijani", locale: nil},
    %{code: "be", name: "Belarusian", locale: nil},
    %{code: "bg", name: "Bulgarian", locale: nil},
    %{code: "bn", name: "Bengali", locale: nil},
    %{code: "bs", name: "Bosnian", locale: nil},
    %{code: "ca", name: "Catalan", locale: nil},
    %{code: "cs", name: "Czech", locale: nil},
    %{code: "cy", name: "Welsh", locale: nil},
    %{code: "da", name: "Danish", locale: nil},
    %{code: "de", name: "German", locale: nil},
    %{code: "el", name: "Greek", locale: nil},
    %{code: "en", name: "English", locale: nil},
    %{code: "es", name: "Spanish", locale: nil},
    %{code: "et", name: "Estonian", locale: nil},
    %{code: "eu", name: "Basque", locale: nil},
    %{code: "fa", name: "Persian", locale: nil},
    %{code: "fi", name: "Finnish", locale: nil},
    %{code: "fr", name: "French", locale: nil},
    %{code: "gl", name: "Galician", locale: nil},
    %{code: "gu", name: "Gujarati", locale: nil},
    %{code: "he", name: "Hebrew", locale: nil},
    %{code: "hi", name: "Hindi", locale: nil},
    %{code: "hr", name: "Croatian", locale: nil},
    %{code: "hu", name: "Hungarian", locale: nil},
    %{code: "id", name: "Indonesian", locale: nil},
    %{code: "is", name: "Icelandic", locale: nil},
    %{code: "it", name: "Italian", locale: nil},
    %{code: "ja", name: "Japanese", locale: nil},
    %{code: "kk", name: "Kazakh", locale: nil},
    %{code: "kn", name: "Kannada", locale: nil},
    %{code: "ko", name: "Korean", locale: nil},
    %{code: "lt", name: "Lithuanian", locale: nil},
    %{code: "lv", name: "Latvian", locale: nil},
    %{code: "mk", name: "Macedonian", locale: nil},
    %{code: "ml", name: "Malayalam", locale: nil},
    %{code: "mr", name: "Marathi", locale: nil},
    %{code: "ms", name: "Malay", locale: nil},
    %{code: "nl", name: "Dutch", locale: nil},
    %{code: "no", name: "Norwegian", locale: nil},
    %{code: "pa", name: "Punjabi", locale: nil},
    %{code: "pl", name: "Polish", locale: nil},
    %{code: "pt", name: "Portuguese", locale: nil},
    %{code: "ro", name: "Romanian", locale: nil},
    %{code: "ru", name: "Russian", locale: nil},
    %{code: "sk", name: "Slovak", locale: nil},
    %{code: "sl", name: "Slovenian", locale: nil},
    %{code: "sq", name: "Albanian", locale: nil},
    %{code: "sr", name: "Serbian", locale: nil},
    %{code: "su", name: "Sundanese", locale: nil},
    %{code: "sv", name: "Swedish", locale: nil},
    %{code: "sw", name: "Swahili", locale: nil},
    %{code: "ta", name: "Tamil", locale: nil},
    %{code: "te", name: "Telugu", locale: nil},
    %{code: "th", name: "Thai", locale: nil},
    %{code: "tl", name: "Tagalog", locale: nil},
    %{code: "tr", name: "Turkish", locale: nil},
    %{code: "uk", name: "Ukrainian", locale: nil},
    %{code: "ur", name: "Urdu", locale: nil},
    %{code: "uz", name: "Uzbek", locale: nil},
    %{code: "vi", name: "Vietnamese", locale: nil},
    %{code: "zh", name: "Chinese", locale: nil}
  ]

  @voices [
    %{
      id: "Daniel",
      name: "Daniel",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Nina",
      name: "Nina",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Bryce",
      name: "Bryce",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Kayla",
      name: "Kayla",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Nora",
      name: "Nora",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Emerson",
      name: "Emerson",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Miles",
      name: "Miles",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Imogen",
      name: "Imogen",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Alistair",
      name: "Alistair",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Bennett",
      name: "Bennett",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Harlan",
      name: "Harlan",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Emma",
      name: "Emma",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Adrian",
      name: "Adrian",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Grace",
      name: "Grace",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Owen",
      name: "Owen",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Mina",
      name: "Mina",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Kenji",
      name: "Kenji",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Rafael",
      name: "Rafael",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Mateo",
      name: "Mateo",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Lucia",
      name: "Lucia",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Oliver",
      name: "Oliver",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Arthur",
      name: "Arthur",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Isla",
      name: "Isla",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Victoria",
      name: "Victoria",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Cooper",
      name: "Cooper",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Mason",
      name: "Mason",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Ruby",
      name: "Ruby",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Arjun",
      name: "Arjun",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Rohan",
      name: "Rohan",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Priya",
      name: "Priya",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Trevor",
      name: "Trevor",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Evan",
      name: "Evan",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Nathan",
      name: "Nathan",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Karan",
      name: "Karan",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Wesley",
      name: "Wesley",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Curtis",
      name: "Curtis",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Preston",
      name: "Preston",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Walter",
      name: "Walter",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Russell",
      name: "Russell",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Tunde",
      name: "Tunde",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Nigel",
      name: "Nigel",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Shane",
      name: "Shane",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Silas",
      name: "Silas",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Reid",
      name: "Reid",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Emilio",
      name: "Emilio",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Dominic",
      name: "Dominic",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Elliot",
      name: "Elliot",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Hugo",
      name: "Hugo",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Sebastian",
      name: "Sebastian",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Haruto",
      name: "Haruto",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Freddie",
      name: "Freddie",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Logan",
      name: "Logan",
      gender: :male,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Poppy",
      name: "Poppy",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Harper",
      name: "Harper",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Cordelia",
      name: "Cordelia",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Reese",
      name: "Reese",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Hazel",
      name: "Hazel",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Juliet",
      name: "Juliet",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Piper",
      name: "Piper",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Reyna",
      name: "Reyna",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Sloane",
      name: "Sloane",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Iris",
      name: "Iris",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Freya",
      name: "Freya",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Brooke",
      name: "Brooke",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Bonnie",
      name: "Bonnie",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Arabella",
      name: "Arabella",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Colleen",
      name: "Colleen",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Margo",
      name: "Margo",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Bianca",
      name: "Bianca",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    },
    %{
      id: "Sari",
      name: "Sari",
      gender: :female,
      language: @supported_languages,
      locale: nil,
      supported_models: @model_ids
    }
  ]

  # Package format name => Soniox `audio_format` value.
  @format_map %{
    "mp3" => "mp3",
    "wav" => "wav",
    "opus" => "opus",
    "aac" => "aac",
    "flac" => "flac",
    "pcm" => "pcm_s16le"
  }

  # Sample rates Soniox accepts per `audio_format`, from
  # https://soniox.com/docs/tts/concepts/audio-formats
  @sample_rates %{
    "pcm_f32le" => [8000, 16000, 24000, 44100, 48000],
    "pcm_s16le" => [8000, 16000, 24000, 44100, 48000],
    "pcm_mulaw" => [8000],
    "pcm_alaw" => [8000],
    "wav" => [8000, 16000, 24000, 44100, 48000],
    "flac" => [16000, 24000, 44100, 48000],
    "mp3" => [16000, 24000, 32000, 44100, 48000],
    "opus" => [8000, 16000, 24000, 48000],
    "aac" => [16000, 24000, 44100, 48000]
  }

  # Codec bitrates Soniox accepts, per `audio_format`. Only the lossy codecs
  # take a bitrate at all — sending one with e.g. `wav` is rejected with a 400.
  @bitrates %{
    "mp3" => [32000, 64000, 96000, 128_000, 192_000, 256_000, 320_000],
    "opus" => [16000, 32000, 64000, 96000, 128_000, 256_000],
    "aac" => [32000, 64000, 96000, 128_000, 192_000, 256_000, 320_000]
  }

  # `HipcallTts.Schema` defaults `:sample_rate` to 22050, which Soniox does not
  # accept for any format. Treat that exact value as "caller did not choose" and
  # let Soniox apply its own per-format default.
  @schema_default_sample_rate 22050

  @speed_min 0.7
  @speed_max 1.3

  # Soniox caps generated audio at 2 minutes of *duration*, not by character
  # count (https://soniox.com/docs/tts/rest-api/limits-and-quotas), and audio
  # past the cap is truncated silently. `max_text_length` therefore has to be a
  # character budget that stays under 120s of speech, and how many characters
  # that is depends on the script.
  #
  # Measured against tts-rt-v2 (voice "Mina", speed 1.0):
  #
  #   Latin/Cyrillic (tr, en) ~15.7 chars/sec  -> 120s ≈ 1880 chars
  #   Japanese (ja)            ~6.1 chars/sec  -> 120s ≈  730 chars
  #   Chinese (zh)             ~4.1 chars/sec  -> 120s ≈  490 chars
  #
  # The default below is sized for Latin/Cyrillic text with margin for the
  # slowest supported speed (0.7). Deployments that synthesize CJK text must
  # lower it, since `capabilities/0` cannot see the request language:
  #
  #     config :hipcall_tts, :soniox_max_text_length, 450
  #
  # Longer text is split by `HipcallTts.TextSplitter` on sentence boundaries and
  # the segments are concatenated.
  @default_max_text_length 1100

  @capabilities %{
    # Soniox supports WebSocket streaming, but `stream/1` is not implemented yet.
    streaming: false,
    formats: ["mp3", "wav", "opus", "aac", "flac", "pcm"],
    sample_rates: [8000, 16000, 24000, 32000, 44100, 48000],
    max_text_length: @default_max_text_length
  }

  @impl HipcallTts.Provider
  @spec generate(HipcallTts.Provider.params()) :: {:ok, binary()} | {:error, any()}
  def generate(params) do
    with :ok <- validate_params(params),
         {:ok, config} <- build_config(params),
         {:ok, request_body} <- build_request_body(params),
         {:ok, response} <- make_request(config, request_body) do
      parse_response(response, params)
    end
  end

  @impl HipcallTts.Provider
  @spec stream(HipcallTts.Provider.params()) :: {:ok, Enumerable.t()} | {:error, any()}
  def stream(_params) do
    {:error, "Streaming not yet implemented"}
  end

  @impl HipcallTts.Provider
  @spec validate_params(HipcallTts.Provider.params()) :: :ok | {:error, String.t()}
  def validate_params(params) do
    params = normalize_params(params)

    cond do
      is_nil(params[:text]) or params[:text] == "" ->
        {:error, "Text cannot be empty"}

      String.length(params[:text]) > max_text_length() ->
        {:error, "Text exceeds maximum length of #{max_text_length()} characters"}

      params[:voice] && not valid_voice?(params[:voice]) ->
        {:error, "Invalid voice: #{params[:voice]}"}

      params[:model] && not valid_model?(params[:model]) ->
        {:error, "Invalid model: #{params[:model]}"}

      params[:language] && is_nil(normalize_language(params[:language])) ->
        {:error, "Invalid language: #{params[:language]}"}

      not is_nil(params[:speed]) and not valid_speed?(params[:speed]) ->
        {:error, "Speed must be between #{@speed_min} and #{@speed_max}"}

      not is_nil(params[:reduce_silence]) and not is_boolean(params[:reduce_silence]) ->
        {:error, "reduce_silence must be a boolean"}

      true ->
        with :ok <- validate_audio_format(params) do
          validate_bitrate(params)
        end
    end
  end

  @impl HipcallTts.Provider
  @spec models() :: [HipcallTts.Provider.model()]
  def models, do: @models

  @impl HipcallTts.Provider
  @spec voices() :: [HipcallTts.Provider.voice()]
  def voices, do: @voices

  @impl HipcallTts.Provider
  @spec languages() :: [HipcallTts.Provider.language()]
  def languages, do: @languages

  @impl HipcallTts.Provider
  @spec compatible_models(String.t()) :: [HipcallTts.Provider.model()]
  def compatible_models(voice_id) do
    case Enum.find(@voices, fn v -> v.id == voice_id end) do
      %{supported_models: supported} when is_list(supported) ->
        Enum.filter(@models, fn m -> m.id in supported end)

      _ ->
        @models
    end
  end

  @impl HipcallTts.Provider
  @spec capabilities() :: HipcallTts.Provider.capabilities()
  def capabilities, do: %{@capabilities | max_text_length: max_text_length()}

  # Private helpers

  defp endpoint_url do
    Application.get_env(:hipcall_tts, :soniox_endpoint_url, @default_endpoint_url)
  end

  # Read from application env rather than `Config.get_provider_config/2` so that
  # introspection never touches (and never raises on) missing credentials.
  defp max_text_length do
    Application.get_env(:hipcall_tts, :soniox_max_text_length, @default_max_text_length)
  end

  defp build_config(params) do
    params = normalize_params(params)

    # If api_key is provided directly in params, use it without resolving system vars
    if api_key = params[:api_key] do
      {:ok, %{api_key: api_key}}
    else
      provider_config = Config.get_provider_config(:soniox, [])

      case Keyword.get(provider_config, :api_key) do
        nil -> {:error, "Soniox API key not configured"}
        api_key -> {:ok, %{api_key: api_key}}
      end
    end
  end

  defp build_request_body(params) do
    params = normalize_params(params)

    provider_config = Config.get_provider_config(:soniox, [])
    default_model = Keyword.get(provider_config, :default_model, "tts-rt-v2")
    default_voice = Keyword.get(provider_config, :default_voice, "Mina")
    default_format = Keyword.get(provider_config, :default_format, "mp3")
    default_language = Keyword.get(provider_config, :default_language, "en")

    audio_format = soniox_format(params[:format] || default_format)

    language =
      normalize_language(params[:language]) || normalize_language(default_language) || "en"

    body = %{
      model: params[:model] || default_model,
      text: params[:text],
      voice: params[:voice] || default_voice,
      language: language,
      audio_format: audio_format
    }

    body =
      body
      |> maybe_put_sample_rate(params[:sample_rate], audio_format)
      |> maybe_put_bitrate(params[:bitrate], audio_format)
      |> maybe_put_speed(params[:speed])
      |> maybe_put_reduce_silence(params[:reduce_silence])

    {:ok, body}
  end

  defp maybe_put_sample_rate(body, nil, _audio_format), do: body

  defp maybe_put_sample_rate(body, @schema_default_sample_rate, _audio_format), do: body

  defp maybe_put_sample_rate(body, sample_rate, audio_format) do
    if sample_rate in Map.get(@sample_rates, audio_format, []) do
      Map.put(body, :sample_rate, sample_rate)
    else
      body
    end
  end

  defp maybe_put_bitrate(body, nil, _audio_format), do: body

  defp maybe_put_bitrate(body, bitrate, audio_format) do
    if bitrate in Map.get(@bitrates, audio_format, []) do
      Map.put(body, :bitrate, bitrate)
    else
      body
    end
  end

  # 1.0 is the schema default and Soniox's own default; omitting it keeps the
  # request minimal and avoids sending a value on models without speed support.
  defp maybe_put_speed(body, nil), do: body
  defp maybe_put_speed(body, speed) when speed == 1.0, do: body
  defp maybe_put_speed(body, speed), do: Map.put(body, :speed, speed)

  defp maybe_put_reduce_silence(body, nil), do: body

  defp maybe_put_reduce_silence(body, reduce_silence) when is_boolean(reduce_silence) do
    Map.put(body, :reduce_silence, reduce_silence)
  end

  defp maybe_put_reduce_silence(body, _), do: body

  defp make_request(config, body) do
    start_time = System.monotonic_time()
    finch_name = Application.get_env(:hipcall_tts, :finch_name, HipcallTtsFinch)

    request =
      Finch.build(
        :post,
        endpoint_url(),
        headers(config),
        Jason.encode!(body)
      )

    case Finch.request(request, finch_name, receive_timeout: 600_000) do
      {:ok, %Finch.Response{status: 200, body: response_body}} ->
        duration = System.monotonic_time() - start_time

        Telemetry.http_request(duration, 200,
          provider: :soniox,
          method: "POST",
          url: endpoint_url()
        )

        {:ok, response_body}

      {:ok, %Finch.Response{status: status, body: body, headers: headers}} ->
        duration = System.monotonic_time() - start_time

        Telemetry.http_request(duration, status,
          provider: :soniox,
          method: "POST",
          url: endpoint_url()
        )

        {:error,
         %{
           message: error_message(body, status),
           code: :http_error,
           status: status,
           headers: headers
         }}

      {:error, reason} ->
        {:error, %{message: "Network error: #{inspect(reason)}", code: :network_error}}
    end
  end

  # Soniox errors look like
  # {"error_code":400,"error_message":"...","error_type":"invalid_request",...}
  defp error_message(body, status) do
    case Jason.decode(body) do
      {:ok, %{"error_message" => message}} when is_binary(message) -> message
      _ -> "HTTP #{status}"
    end
  end

  defp parse_response(audio_binary, _params) do
    {:ok, audio_binary}
  end

  defp headers(config) do
    [
      {"Authorization", "Bearer #{config.api_key}"},
      {"Content-Type", "application/json"}
    ]
  end

  defp normalize_params(params) when is_map(params) do
    params
    |> Map.to_list()
    |> normalize_params()
  end

  defp normalize_params(params) when is_list(params) do
    params
    |> Enum.map(fn
      {key, value} when is_atom(key) -> {key, value}
      {key, value} when is_binary(key) -> {String.to_existing_atom(key), value}
      other -> other
    end)
  end

  # Soniox expects a bare ISO code ("tr"), but callers commonly pass a locale
  # ("tr-TR", "en_US"). Returns nil when the language is not supported.
  defp normalize_language(nil), do: nil

  defp normalize_language(language) when is_binary(language) do
    code =
      language
      |> String.trim()
      |> String.replace("_", "-")
      |> String.split("-")
      |> List.first()
      |> to_string()
      |> String.downcase()

    if code in @supported_languages, do: code, else: nil
  end

  defp normalize_language(_), do: nil

  defp soniox_format(format) when is_binary(format) do
    Map.get(@format_map, format, format)
  end

  defp soniox_format(_), do: "mp3"

  defp validate_audio_format(params) do
    format = params[:format]

    cond do
      is_nil(format) ->
        :ok

      Map.has_key?(@format_map, format) or Map.has_key?(@sample_rates, format) ->
        :ok

      true ->
        {:error, "Invalid format: #{format}"}
    end
  end

  # `:bitrate` only ever arrives explicitly (via `provider_opts`), so an
  # unusable value is a caller mistake worth reporting rather than dropping.
  # The format falls back to the schema default rather than reading provider
  # config, so that validation never touches credential resolution.
  defp validate_bitrate(params) do
    case params[:bitrate] do
      nil ->
        :ok

      bitrate ->
        audio_format = soniox_format(params[:format] || "mp3")

        case Map.fetch(@bitrates, audio_format) do
          :error ->
            {:error, "Bitrate is not supported for the #{audio_format} format"}

          {:ok, allowed} ->
            if bitrate in allowed do
              :ok
            else
              {:error,
               "Invalid bitrate for #{audio_format}: #{inspect(bitrate)} " <>
                 "(supported: #{Enum.join(allowed, ", ")})"}
            end
        end
    end
  end

  defp valid_speed?(speed) when is_number(speed) do
    speed >= @speed_min and speed <= @speed_max
  end

  defp valid_speed?(_), do: false

  defp valid_voice?(voice_id) do
    Enum.any?(@voices, fn voice -> voice.id == voice_id end)
  end

  defp valid_model?(model_id) do
    Enum.any?(@models, fn model -> model.id == model_id end)
  end
end
