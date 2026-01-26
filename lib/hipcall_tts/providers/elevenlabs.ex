defmodule HipcallTts.Providers.ElevenLabs do
  @behaviour HipcallTts.Provider

  @moduledoc """
  ElevenLabs Text-to-Speech provider.

  Implements `HipcallTts.Provider` using the ElevenLabs Text-to-Speech API.

  Note: ElevenLabs supports streaming, but `stream/1` is not implemented yet in this package,
  so `capabilities().streaming` is currently `false`.
  """

  alias HipcallTts.Config
  alias HipcallTts.Telemetry

  @default_endpoint_url "https://api.elevenlabs.io/v1/text-to-speech"

  @models [
    %{
      id: "eleven_multilingual_v2",
      name: "Eleven Multilingual v2",
      description:
        "Our most life-like, emotionally rich mode in 29 languages. Best for voice overs, audiobooks, post-production, or any other content creation needs.",
      languages: [
        "en",
        "ja",
        "zh",
        "de",
        "hi",
        "fr",
        "ko",
        "pt",
        "it",
        "es",
        "id",
        "nl",
        "tr",
        "fil",
        "pl",
        "sv",
        "bg",
        "ro",
        "ar",
        "cs",
        "el",
        "fi",
        "hr",
        "ms",
        "sk",
        "da",
        "ta",
        "uk",
        "ru"
      ]
    },
    %{
      id: "eleven_flash_v2_5",
      name: "Eleven Flash v2.5",
      description:
        "Our ultra low latency model in 32 languages. Ideal for conversational use cases.",
      languages: [
        "en",
        "ja",
        "zh",
        "de",
        "hi",
        "fr",
        "ko",
        "pt",
        "it",
        "es",
        "ru",
        "id",
        "nl",
        "tr",
        "fil",
        "pl",
        "sv",
        "bg",
        "ro",
        "ar",
        "cs",
        "el",
        "fi",
        "hr",
        "ms",
        "sk",
        "da",
        "ta",
        "uk",
        "hu",
        "no",
        "vi"
      ]
    }
  ]

  # Model-specific max text lengths from API
  @model_max_lengths %{
    "eleven_multilingual_v2" => 10000,
    "eleven_flash_v2_5" => 40000
  }

  @voices [
    %{id: "Xb7hH8MSUJpSbSDYk0k2", name: "Alice", gender: :female, language: "en", locale: nil},
    %{id: "nPczCjzI2devNBz1zQrb", name: "Brian", gender: :male, language: "en", locale: nil},
    %{id: "N2lVS1w4EtoT3dr4eOWO", name: "Callum", gender: :male, language: "en", locale: nil},
    %{id: "KbaseEXyT9EE0CQLEfbB", name: "Belma", gender: :female, language: "tr", locale: nil},
    %{id: "IuRRIAcbQK5AQk1XevPj", name: "Doga", gender: :male, language: "tr", locale: nil},
    %{id: "zCagxWNd7QOsCjiHDrGR", name: "İpek", gender: :female, language: "tr", locale: nil},
    %{id: "axtmxCPnqPghs9C5SjJ8", name: "Meloxia", gender: :female, language: "tr", locale: nil},
    %{id: "Q5n6GDIjpN0pLOlycRFT", name: "Yunus", gender: :male, language: "tr", locale: nil}
  ]

  @languages [
    %{code: "ar", name: "Arabic", locale: nil},
    %{code: "bg", name: "Bulgarian", locale: nil},
    %{code: "cs", name: "Czech", locale: nil},
    %{code: "da", name: "Danish", locale: nil},
    %{code: "de", name: "German", locale: nil},
    %{code: "el", name: "Greek", locale: nil},
    %{code: "en", name: "English", locale: nil},
    %{code: "es", name: "Spanish", locale: nil},
    %{code: "fi", name: "Finnish", locale: nil},
    %{code: "fil", name: "Filipino", locale: nil},
    %{code: "fr", name: "French", locale: nil},
    %{code: "hi", name: "Hindi", locale: nil},
    %{code: "hr", name: "Croatian", locale: nil},
    %{code: "hu", name: "Hungarian", locale: nil},
    %{code: "id", name: "Indonesian", locale: nil},
    %{code: "it", name: "Italian", locale: nil},
    %{code: "ja", name: "Japanese", locale: nil},
    %{code: "ko", name: "Korean", locale: nil},
    %{code: "ms", name: "Malay", locale: nil},
    %{code: "nl", name: "Dutch", locale: nil},
    %{code: "no", name: "Norwegian", locale: nil},
    %{code: "pl", name: "Polish", locale: nil},
    %{code: "pt", name: "Portuguese", locale: nil},
    %{code: "ro", name: "Romanian", locale: nil},
    %{code: "ru", name: "Russian", locale: nil},
    %{code: "sk", name: "Slovak", locale: nil},
    %{code: "sv", name: "Swedish", locale: nil},
    %{code: "ta", name: "Tamil", locale: nil},
    %{code: "tr", name: "Turkish", locale: nil},
    %{code: "uk", name: "Ukrainian", locale: nil},
    %{code: "vi", name: "Vietnamese", locale: nil},
    %{code: "zh", name: "Chinese", locale: nil}
  ]

  @capabilities %{
    # ElevenLabs supports streaming, but `stream/1` is not implemented yet in this package.
    streaming: false,
    formats: ["mp3", "pcm", "ulaw_8000"],
    sample_rates: [22050, 24000, 44100, 48000],
    max_text_length: 40000
  }

  @impl HipcallTts.Provider
  @spec generate(HipcallTts.Provider.params()) :: {:ok, binary()} | {:error, any()}
  def generate(params) do
    with :ok <- validate_params(params),
         {:ok, config} <- build_config(params),
         {:ok, request_body, voice_id} <- build_request_body(params),
         {:ok, response} <- make_request(config, request_body, voice_id) do
      parse_response(response, params)
    end
  end

  @impl HipcallTts.Provider
  @spec stream(HipcallTts.Provider.params()) :: {:ok, Enumerable.t()} | {:error, any()}
  def stream(_params) do
    {:error,
     %{code: :not_implemented, message: "Streaming not yet implemented", provider: :elevenlabs}}
  end

  @impl HipcallTts.Provider
  @spec validate_params(HipcallTts.Provider.params()) :: :ok | {:error, String.t()}
  def validate_params(params) do
    params = normalize_params(params)

    max_length =
      if model = params[:model] do
        Map.get(@model_max_lengths, model, @capabilities.max_text_length)
      else
        @capabilities.max_text_length
      end

    cond do
      is_nil(params[:text]) or params[:text] == "" ->
        {:error, "Text cannot be empty"}

      String.length(params[:text]) > max_length ->
        model_msg =
          if params[:model] do
            " for model #{params[:model]}"
          else
            ""
          end

        {:error, "Text exceeds maximum length of #{max_length} characters#{model_msg}"}

      params[:voice] && not valid_voice?(params[:voice]) ->
        {:error, "Invalid voice: #{params[:voice]}"}

      params[:model] && not valid_model?(params[:model]) ->
        {:error, "Invalid model: #{params[:model]}"}

      params[:format] && params[:format] not in @capabilities.formats ->
        {:error,
         "Invalid format: #{params[:format]} (supported: #{Enum.join(@capabilities.formats, ", ")})"}

      true ->
        :ok
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
  @spec capabilities() :: HipcallTts.Provider.capabilities()
  def capabilities, do: @capabilities

  # Private helpers

  defp endpoint_url do
    Application.get_env(:hipcall_tts, :elevenlabs_endpoint_url, @default_endpoint_url)
  end

  defp build_config(params) do
    params = normalize_params(params)

    # If api_key is provided directly in params, use it without resolving system vars
    if api_key = params[:api_key] do
      {:ok, %{api_key: api_key}}
    else
      # Otherwise, try to get from config
      provider_config = Config.get_provider_config(:elevenlabs, [])

      api_key = Keyword.get(provider_config, :api_key)

      if api_key do
        {:ok, %{api_key: api_key}}
      else
        {:error, "ElevenLabs API key not configured"}
      end
    end
  end

  defp build_request_body(params) do
    params = normalize_params(params)

    text = params[:text]
    # Get defaults from config
    provider_config = Config.get_provider_config(:elevenlabs, [])
    default_voice = Keyword.get(provider_config, :default_voice, "Xb7hH8MSUJpSbSDYk0k2")
    default_model = Keyword.get(provider_config, :default_model, "eleven_flash_v2_5")

    voice_id = params[:voice] || default_voice
    model_id = params[:model] || default_model

    # Get default format from config
    default_format = Keyword.get(provider_config, :default_format, "mp3")
    format = params[:format] || default_format

    # ElevenLabs API requires output_format in format: "{codec}_{samplerate}_{bitrate}"
    # See: https://elevenlabs.io/docs/api-reference/text-to-speech
    # Default format per API docs is "mp3_44100_128", but we use "mp3_22050_32" for compatibility
    output_format =
      case format do
        "pcm" -> "pcm_22050"
        "ulaw_8000" -> "ulaw_8000"
        _ -> "mp3_22050_32"
      end

    body = %{
      text: text,
      model_id: model_id,
      output_format: output_format
    }

    # Add voice_settings if provided
    body =
      if params[:speed] || params[:stability] || params[:similarity_boost] || params[:style] ||
           params[:use_speaker_boost] do
        voice_settings = %{}

        voice_settings =
          if params[:speed],
            do: Map.put(voice_settings, :speed, params[:speed]),
            else: voice_settings

        voice_settings =
          if params[:stability],
            do: Map.put(voice_settings, :stability, params[:stability]),
            else: voice_settings

        voice_settings =
          if params[:similarity_boost],
            do: Map.put(voice_settings, :similarity_boost, params[:similarity_boost]),
            else: voice_settings

        voice_settings =
          if params[:style],
            do: Map.put(voice_settings, :style, params[:style]),
            else: voice_settings

        voice_settings =
          if params[:use_speaker_boost] != nil,
            do: Map.put(voice_settings, :use_speaker_boost, params[:use_speaker_boost]),
            else: voice_settings

        Map.put(body, :voice_settings, voice_settings)
      else
        body
      end

    {:ok, body, voice_id}
  end

  defp make_request(config, body, voice_id) do
    start_time = System.monotonic_time()
    finch_name = Application.get_env(:hipcall_tts, :finch_name, HipcallTtsFinch)

    url = "#{endpoint_url()}/#{voice_id}"

    request =
      Finch.build(
        :post,
        url,
        headers(config),
        Jason.encode!(body)
      )

    case Finch.request(request, finch_name, receive_timeout: 600_000) do
      {:ok, %Finch.Response{status: 200, body: response_body}} ->
        duration = System.monotonic_time() - start_time

        Telemetry.http_request(duration, 200,
          provider: :elevenlabs,
          method: "POST",
          url: url
        )

        {:ok, response_body}

      {:ok, %Finch.Response{status: status, body: body, headers: headers}} ->
        duration = System.monotonic_time() - start_time

        Telemetry.http_request(duration, status,
          provider: :elevenlabs,
          method: "POST",
          url: url
        )

        error_message =
          case Jason.decode(body) do
            {:ok, decoded} ->
              Map.get(decoded, "detail", %{})
              |> case do
                %{"message" => message} when is_binary(message) -> message
                message when is_binary(message) -> message
                _ -> "HTTP #{status}"
              end

            _ ->
              "HTTP #{status}"
          end

        {:error, %{message: error_message, code: :http_error, status: status, headers: headers}}

      {:error, reason} ->
        {:error, %{message: "Network error: #{inspect(reason)}", code: :network_error}}
    end
  end

  defp parse_response(audio_binary, _params) do
    {:ok, audio_binary}
  end

  defp headers(config) do
    [
      {"xi-api-key", config.api_key},
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

  defp valid_voice?(voice_id) do
    is_binary(voice_id) and voice_id != ""
  end

  defp valid_model?(model_id) do
    Enum.any?(@models, fn model -> model.id == model_id end)
  end
end
