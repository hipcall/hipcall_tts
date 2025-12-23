defmodule HipcallTts.Providers.OpenAI do
  @behaviour HipcallTts.Provider

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

  @voices [
    %{id: "alloy", name: "Alloy", gender: :neutral, language: "en", locale: nil},
    %{id: "echo", name: "Echo", gender: :male, language: "en", locale: nil},
    %{id: "fable", name: "Fable", gender: :neutral, language: "en", locale: nil},
    %{id: "onyx", name: "Onyx", gender: :male, language: "en", locale: nil},
    %{id: "nova", name: "Nova", gender: :female, language: "en", locale: nil},
    %{id: "shimmer", name: "Shimmer", gender: :female, language: "en", locale: nil}
  ]

  @languages [
    %{code: "en", name: "English", locale: nil},
    %{code: "tr", name: "Turkish", locale: nil},
    %{code: "de", name: "German", locale: nil},
    %{code: "es", name: "Spanish", locale: nil},
    %{code: "fr", name: "French", locale: nil},
    %{code: "it", name: "Italian", locale: nil},
    %{code: "pt", name: "Portuguese", locale: nil},
    %{code: "ru", name: "Russian", locale: nil},
    %{code: "ja", name: "Japanese", locale: nil},
    %{code: "ko", name: "Korean", locale: nil},
    %{code: "zh", name: "Chinese", locale: nil}
  ]

  @capabilities %{
    streaming: true,
    formats: ["mp3", "opus", "aac", "flac"],
    sample_rates: [22050, 44100],
    max_text_length: 4096
  }

  @impl HipcallTts.Provider
  def generate(params) do
    with :ok <- validate_params(params),
         {:ok, config} <- build_config(params),
         {:ok, request_body} <- build_request_body(params),
         {:ok, response} <- make_request(config, request_body) do
      parse_response(response, params)
    end
  end

  @impl HipcallTts.Provider
  def stream(_params) do
    {:error, "Streaming not yet implemented"}
  end

  @impl HipcallTts.Provider
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
  def models, do: @models

  @impl HipcallTts.Provider
  def voices, do: @voices

  @impl HipcallTts.Provider
  def languages, do: @languages

  @impl HipcallTts.Provider
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

    body = %{
      model: params[:model] || "tts-1",
      input: params[:text],
      voice: params[:voice] || "nova",
      response_format: params[:format] || "mp3"
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
