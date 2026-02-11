defmodule HipcallTts.Providers.OpenAI do
  @behaviour HipcallTts.Provider

  @moduledoc """
  OpenAI Text-to-Speech provider.

  Implements `HipcallTts.Provider` using the OpenAI Audio Speech endpoint.

  Note: OpenAI supports streaming, but `stream/1` is not implemented yet in this package,
  so `capabilities().streaming` is currently `false`.
  """

  alias HipcallTts.Config
  alias HipcallTts.Telemetry

  @default_endpoint_url "https://api.openai.com/v1/audio/speech"

  @models [
    %{
      id: "tts-1",
      name: "TTS 1",
      description: "Standard quality, faster generation",
      languages: nil
    },
    %{
      id: "tts-1-hd",
      name: "TTS 1 HD",
      description: "High quality, slower generation",
      languages: nil
    }
  ]

  @supported_languages [
    "af",
    "ar",
    "hy",
    "az",
    "be",
    "bs",
    "bg",
    "ca",
    "zh",
    "hr",
    "cs",
    "da",
    "nl",
    "en",
    "et",
    "fi",
    "fr",
    "gl",
    "de",
    "el",
    "he",
    "hi",
    "hu",
    "is",
    "id",
    "it",
    "ja",
    "kn",
    "kk",
    "ko",
    "lv",
    "lt",
    "mk",
    "ms",
    "mr",
    "mi",
    "ne",
    "no",
    "fa",
    "pl",
    "pt",
    "ro",
    "ru",
    "sr",
    "sk",
    "sl",
    "es",
    "sw",
    "sv",
    "tl",
    "ta",
    "th",
    "tr",
    "uk",
    "ur",
    "vi",
    "cy"
  ]

  @voices [
    %{id: "alloy", name: "Alloy", gender: :neutral, language: @supported_languages, locale: nil},
    %{id: "ash", name: "Ash", gender: :male, language: @supported_languages, locale: nil},
    %{id: "ballad", name: "Ballad", gender: :male, language: @supported_languages, locale: nil},
    %{id: "coral", name: "Coral", gender: :female, language: @supported_languages, locale: nil},
    %{id: "echo", name: "Echo", gender: :male, language: @supported_languages, locale: nil},
    %{id: "fable", name: "Fable", gender: :neutral, language: @supported_languages, locale: nil},
    %{id: "nova", name: "Nova", gender: :female, language: @supported_languages, locale: nil},
    %{id: "onyx", name: "Onyx", gender: :male, language: @supported_languages, locale: nil},
    %{id: "sage", name: "Sage", gender: :female, language: @supported_languages, locale: nil},
    %{
      id: "shimmer",
      name: "Shimmer",
      gender: :female,
      language: @supported_languages,
      locale: nil
    },
    %{id: "verse", name: "Verse", gender: :male, language: @supported_languages, locale: nil},
    %{id: "marin", name: "Marin", gender: :female, language: @supported_languages, locale: nil},
    %{id: "cedar", name: "Cedar", gender: :male, language: @supported_languages, locale: nil}
  ]

  @languages [
    %{code: "af", name: "Afrikaans", locale: nil},
    %{code: "ar", name: "Arabic", locale: nil},
    %{code: "hy", name: "Armenian", locale: nil},
    %{code: "az", name: "Azerbaijani", locale: nil},
    %{code: "be", name: "Belarusian", locale: nil},
    %{code: "bs", name: "Bosnian", locale: nil},
    %{code: "bg", name: "Bulgarian", locale: nil},
    %{code: "ca", name: "Catalan", locale: nil},
    %{code: "zh", name: "Chinese", locale: nil},
    %{code: "hr", name: "Croatian", locale: nil},
    %{code: "cs", name: "Czech", locale: nil},
    %{code: "da", name: "Danish", locale: nil},
    %{code: "nl", name: "Dutch", locale: nil},
    %{code: "en", name: "English", locale: nil},
    %{code: "et", name: "Estonian", locale: nil},
    %{code: "fi", name: "Finnish", locale: nil},
    %{code: "fr", name: "French", locale: nil},
    %{code: "gl", name: "Galician", locale: nil},
    %{code: "de", name: "German", locale: nil},
    %{code: "el", name: "Greek", locale: nil},
    %{code: "he", name: "Hebrew", locale: nil},
    %{code: "hi", name: "Hindi", locale: nil},
    %{code: "hu", name: "Hungarian", locale: nil},
    %{code: "is", name: "Icelandic", locale: nil},
    %{code: "id", name: "Indonesian", locale: nil},
    %{code: "it", name: "Italian", locale: nil},
    %{code: "ja", name: "Japanese", locale: nil},
    %{code: "kn", name: "Kannada", locale: nil},
    %{code: "kk", name: "Kazakh", locale: nil},
    %{code: "ko", name: "Korean", locale: nil},
    %{code: "lv", name: "Latvian", locale: nil},
    %{code: "lt", name: "Lithuanian", locale: nil},
    %{code: "mk", name: "Macedonian", locale: nil},
    %{code: "ms", name: "Malay", locale: nil},
    %{code: "mr", name: "Marathi", locale: nil},
    %{code: "mi", name: "Maori", locale: nil},
    %{code: "ne", name: "Nepali", locale: nil},
    %{code: "no", name: "Norwegian", locale: nil},
    %{code: "fa", name: "Persian", locale: nil},
    %{code: "pl", name: "Polish", locale: nil},
    %{code: "pt", name: "Portuguese", locale: nil},
    %{code: "ro", name: "Romanian", locale: nil},
    %{code: "ru", name: "Russian", locale: nil},
    %{code: "sr", name: "Serbian", locale: nil},
    %{code: "sk", name: "Slovak", locale: nil},
    %{code: "sl", name: "Slovenian", locale: nil},
    %{code: "es", name: "Spanish", locale: nil},
    %{code: "sw", name: "Swahili", locale: nil},
    %{code: "sv", name: "Swedish", locale: nil},
    %{code: "tl", name: "Tagalog", locale: nil},
    %{code: "ta", name: "Tamil", locale: nil},
    %{code: "th", name: "Thai", locale: nil},
    %{code: "tr", name: "Turkish", locale: nil},
    %{code: "uk", name: "Ukrainian", locale: nil},
    %{code: "ur", name: "Urdu", locale: nil},
    %{code: "vi", name: "Vietnamese", locale: nil},
    %{code: "cy", name: "Welsh", locale: nil}
  ]

  @capabilities %{
    # OpenAI supports streaming, but `stream/1` is not implemented yet in this package.
    streaming: false,
    formats: ["mp3", "opus", "aac", "flac"],
    sample_rates: [22050, 44100],
    max_text_length: 4096
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

      String.length(params[:text]) > @capabilities.max_text_length ->
        {:error, "Text exceeds maximum length of #{@capabilities.max_text_length} characters"}

      params[:voice] && not valid_voice?(params[:voice]) ->
        {:error, "Invalid voice: #{params[:voice]}"}

      params[:model] && not valid_model?(params[:model]) ->
        {:error, "Invalid model: #{params[:model]}"}

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
    Application.get_env(:hipcall_tts, :openai_endpoint_url, @default_endpoint_url)
  end

  defp build_config(params) do
    params = normalize_params(params)

    # If api_key is provided directly in params, use it without resolving system vars
    if api_key = params[:api_key] do
      {:ok,
       %{
         api_key: api_key,
         api_organization: params[:api_organization]
       }}
    else
      # Otherwise, try to get from config
      provider_config =
        Config.get_provider_config(:openai, Keyword.take(params, [:api_organization]))

      api_key = Keyword.get(provider_config, :api_key)

      if api_key do
        {:ok,
         %{api_key: api_key, api_organization: Keyword.get(provider_config, :api_organization)}}
      else
        {:error, "OpenAI API key not configured"}
      end
    end
  end

  defp build_request_body(params) do
    params = normalize_params(params)

    # Get defaults from config
    provider_config = Config.get_provider_config(:openai, [])
    default_model = Keyword.get(provider_config, :default_model, "tts-1")
    default_voice = Keyword.get(provider_config, :default_voice, "nova")
    default_format = Keyword.get(provider_config, :default_format, "mp3")

    body = %{
      model: params[:model] || default_model,
      input: params[:text],
      voice: params[:voice] || default_voice,
      response_format: params[:format] || default_format
    }

    body =
      if params[:speed] do
        Map.put(body, :speed, params[:speed])
      else
        body
      end

    {:ok, body}
  end

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
          provider: :openai,
          method: "POST",
          url: endpoint_url()
        )

        {:ok, response_body}

      {:ok, %Finch.Response{status: status, body: body, headers: headers}} ->
        duration = System.monotonic_time() - start_time

        Telemetry.http_request(duration, status,
          provider: :openai,
          method: "POST",
          url: endpoint_url()
        )

        error_message =
          case Jason.decode(body) do
            {:ok, decoded} ->
              Map.get(decoded, "error", %{}) |> Map.get("message", "Unknown error")

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
    headers = [
      {"Authorization", "Bearer #{config.api_key}"},
      {"Content-Type", "application/json"}
    ]

    if config.api_organization do
      [{"OpenAI-Organization", config.api_organization} | headers]
    else
      headers
    end
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
    Enum.any?(@voices, fn voice -> voice.id == voice_id end)
  end

  defp valid_model?(model_id) do
    Enum.any?(@models, fn model -> model.id == model_id end)
  end
end
