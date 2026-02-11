defmodule HipcallTts.Providers.Polly do
  @behaviour HipcallTts.Provider

  @moduledoc """
  Amazon Polly Text-to-Speech provider.

  Implements `HipcallTts.Provider` by calling Polly's `SynthesizeSpeech` endpoint and
  signing requests with AWS Signature Version 4 (SigV4).

  Streaming is not supported in this MVP (`capabilities().streaming == false`).
  """

  alias HipcallTts.{Config, Telemetry}

  @service "polly"
  @default_region "us-east-1"
  @default_endpoint_template "https://polly.%{region}.amazonaws.com/v1/speech"

  @models [
    %{
      id: "standard",
      name: "Standard",
      description: "AWS Polly standard engine",
      languages: nil
    },
    %{
      id: "neural",
      name: "Neural",
      description: "AWS Polly neural engine (when supported by voice/region)",
      languages: nil
    }
  ]

  @voices [
    # Turkish (tr-TR)
    %{id: "Filiz", name: "Filiz", gender: :female, language: "tr", locale: "tr-TR"},
    %{id: "Burcu", name: "Burcu", gender: :female, language: "tr", locale: "tr-TR"},
    # English (en-GB)
    %{id: "Amy", name: "Amy", gender: :female, language: "en", locale: "en-GB"},
    %{id: "Emma", name: "Emma", gender: :female, language: "en", locale: "en-GB"},
    %{id: "Brian", name: "Brian", gender: :male, language: "en", locale: "en-GB"},
    %{id: "Arthur", name: "Arthur", gender: :male, language: "en", locale: "en-GB"},
    # German (de-DE)
    %{id: "Marlene", name: "Marlene", gender: :female, language: "de", locale: "de-DE"},
    %{id: "Daniel", name: "Daniel", gender: :male, language: "de", locale: "de-DE"},
    %{id: "Vicki", name: "Vicki", gender: :female, language: "de", locale: "de-DE"},
    # English (en-US)
    %{id: "Danielle", name: "Danielle", gender: :female, language: "en", locale: "en-US"},
    %{id: "Gregory", name: "Gregory", gender: :male, language: "en", locale: "en-US"},
    %{id: "Ivy", name: "Ivy", gender: :female, language: "en", locale: "en-US"},
    %{id: "Joanna", name: "Joanna", gender: :female, language: "en", locale: "en-US"},
    %{id: "Kendra", name: "Kendra", gender: :female, language: "en", locale: "en-US"},
    %{id: "Kimberly", name: "Kimberly", gender: :female, language: "en", locale: "en-US"},
    %{id: "Salli", name: "Salli", gender: :female, language: "en", locale: "en-US"},
    %{id: "Joey", name: "Joey", gender: :male, language: "en", locale: "en-US"},
    %{id: "Justin", name: "Justin", gender: :male, language: "en", locale: "en-US"},
    %{id: "Kevin", name: "Kevin", gender: :male, language: "en", locale: "en-US"},
    %{id: "Matthew", name: "Matthew", gender: :male, language: "en", locale: "en-US"},
    %{id: "Ruth", name: "Ruth", gender: :female, language: "en", locale: "en-US"},
    %{id: "Stephen", name: "Stephen", gender: :male, language: "en", locale: "en-US"}
  ]

  @languages [
    %{code: "tr", name: "Turkish", locale: "tr-TR"},
    %{code: "en", name: "English", locale: "en-GB"},
    %{code: "de", name: "German", locale: "de-DE"},
    %{code: "en", name: "English", locale: "en-US"}
  ]

  @capabilities %{
    streaming: false,
    formats: ["mp3", "ogg_vorbis", "pcm"],
    sample_rates: [8000, 16000, 22050],
    max_text_length: 3000
  }

  @impl HipcallTts.Provider
  @spec generate(HipcallTts.Provider.params()) :: {:ok, binary()} | {:error, any()}
  def generate(params) do
    with :ok <- validate_params(params),
         params <- normalize_params(params),
         {:ok, config} <- build_config(params),
         {:ok, body} <- build_request_body(params),
         {:ok, audio} <- make_request(config, body) do
      {:ok, audio}
    end
  end

  @impl HipcallTts.Provider
  @spec stream(HipcallTts.Provider.params()) :: {:ok, Enumerable.t()} | {:error, any()}
  def stream(_params), do: {:error, "Streaming not supported for Polly (MVP)"}

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
        {:error, "Invalid model/engine: #{params[:model]} (expected \"standard\" or \"neural\")"}

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

  # ---- Config / Endpoint ----

  defp endpoint_url(region) do
    Application.get_env(:hipcall_tts, :polly_endpoint_url) ||
      String.replace(@default_endpoint_template, "%{region}", region)
  end

  defp build_config(params) do
    cfg =
      Config.get_provider_config(
        :polly,
        take_keys(params, [:access_key_id, :secret_access_key, :region, :session_token])
      )

    cfg =
      if Keyword.has_key?(cfg, :access_key_id) and Keyword.has_key?(cfg, :secret_access_key) do
        cfg
      else
        Config.get_provider_config(
          :aws_polly,
          take_keys(params, [:access_key_id, :secret_access_key, :region, :session_token])
        )
      end

    access_key_id = Keyword.get(cfg, :access_key_id)
    secret_access_key = Keyword.get(cfg, :secret_access_key)
    region = Keyword.get(cfg, :region, @default_region)
    session_token = Keyword.get(cfg, :session_token)

    cond do
      is_nil(access_key_id) or access_key_id == "" ->
        {:error, "AWS access_key_id not configured"}

      is_nil(secret_access_key) or secret_access_key == "" ->
        {:error, "AWS secret_access_key not configured"}

      true ->
        {:ok,
         %{
           access_key_id: access_key_id,
           secret_access_key: secret_access_key,
           region: region,
           session_token: session_token,
           endpoint_url: endpoint_url(region)
         }}
    end
  end

  defp build_request_body(params) do
    text = params[:text]

    # Get defaults from config
    provider_config = Config.get_provider_config(:polly, [])
    default_voice = Keyword.get(provider_config, :default_voice, "Joanna")
    default_model = Keyword.get(provider_config, :default_model, "standard")
    default_format = Keyword.get(provider_config, :default_format, "mp3")

    voice = params[:voice] || default_voice

    engine =
      case params[:model] do
        nil -> default_model
        "standard" -> "standard"
        "neural" -> "neural"
        other -> other
      end

    output_format = params[:format] || default_format

    text_type =
      if is_binary(text) and String.contains?(text, "<speak>") do
        "ssml"
      else
        "text"
      end

    body =
      %{
        "OutputFormat" => output_format,
        "Text" => text,
        "VoiceId" => voice,
        "Engine" => engine,
        "TextType" => text_type
      }
      |> maybe_put_sample_rate(params)

    {:ok, body}
  end

  defp maybe_put_sample_rate(body, %{sample_rate: sr}) when is_integer(sr) do
    Map.put(body, "SampleRate", Integer.to_string(sr))
  end

  defp maybe_put_sample_rate(body, _), do: body

  defp make_request(config, body_map) do
    start_time = System.monotonic_time()
    finch_name = Application.get_env(:hipcall_tts, :finch_name, HipcallTtsFinch)

    url = config.endpoint_url
    body_json = Jason.encode!(body_map)

    {headers, amz_date} = signed_headers(config, url, body_json)

    request = Finch.build(:post, url, headers, body_json)

    case Finch.request(request, finch_name, receive_timeout: 600_000) do
      {:ok, %Finch.Response{status: 200, body: audio}} ->
        Telemetry.http_request(System.monotonic_time() - start_time, 200,
          provider: :polly,
          method: "POST",
          url: url
        )

        {:ok, audio}

      {:ok, %Finch.Response{status: status, body: body, headers: headers}} ->
        Telemetry.http_request(System.monotonic_time() - start_time, status,
          provider: :polly,
          method: "POST",
          url: url
        )

        {:error,
         %{code: :http_error, status: status, body: body, headers: headers, amz_date: amz_date}}

      {:error, reason} ->
        {:error, %{code: :network_error, message: "Network error: #{inspect(reason)}"}}
    end
  end

  defp signed_headers(config, url, body) do
    {:ok, uri} = URI.new(url)

    host = uri.host
    canonical_uri = if uri.path in [nil, ""], do: "/", else: uri.path
    canonical_query = canonical_query_string(uri.query)

    amz_date = amz_date()
    date_stamp = String.slice(amz_date, 0, 8)

    headers =
      [
        {"host", host},
        {"content-type", "application/x-amz-json-1.1"},
        {"x-amz-date", amz_date}
      ]
      |> maybe_put_token(config.session_token)

    {canonical_headers, signed_headers} = canonicalize_headers(headers)
    payload_hash = sha256_hex(body)

    canonical_request =
      [
        "POST",
        canonical_uri,
        canonical_query,
        canonical_headers,
        signed_headers,
        payload_hash
      ]
      |> Enum.join("\n")

    credential_scope = "#{date_stamp}/#{config.region}/#{@service}/aws4_request"

    string_to_sign =
      [
        "AWS4-HMAC-SHA256",
        amz_date,
        credential_scope,
        sha256_hex(canonical_request)
      ]
      |> Enum.join("\n")

    signature =
      signing_key(config.secret_access_key, date_stamp, config.region, @service)
      |> hmac_hex(string_to_sign)

    authorization =
      "AWS4-HMAC-SHA256 Credential=#{config.access_key_id}/#{credential_scope}, SignedHeaders=#{signed_headers}, Signature=#{signature}"

    final_headers =
      headers
      |> Enum.map(fn {k, v} -> {String.capitalize(k), v} end)
      |> Kernel.++([{"Authorization", authorization}])

    {final_headers, amz_date}
  end

  defp canonical_query_string(nil), do: ""

  defp canonical_query_string(query) do
    query
    |> URI.decode_query()
    |> Enum.map(fn {k, v} -> {aws_encode(k), aws_encode(v)} end)
    |> Enum.sort()
    |> Enum.map_join("&", fn {k, v} -> "#{k}=#{v}" end)
  end

  defp canonicalize_headers(headers) do
    normalized =
      headers
      |> Enum.map(fn {k, v} -> {String.downcase(k), String.trim(v)} end)
      |> Enum.sort()

    canonical_headers =
      normalized
      |> Enum.map_join("", fn {k, v} -> "#{k}:#{v}\n" end)

    signed_headers =
      normalized
      |> Enum.map_join(";", fn {k, _v} -> k end)

    {canonical_headers, signed_headers}
  end

  defp signing_key(secret, date_stamp, region, service) do
    ("AWS4" <> secret)
    |> hmac(date_stamp)
    |> hmac(region)
    |> hmac(service)
    |> hmac("aws4_request")
  end

  defp hmac(key, data), do: :crypto.mac(:hmac, :sha256, key, data)
  defp hmac_hex(key, data), do: hmac(key, data) |> Base.encode16(case: :lower)
  defp sha256_hex(data), do: :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)

  defp amz_date do
    # YYYYMMDD'T'HHMMSS'Z'
    DateTime.utc_now()
    |> Calendar.strftime("%Y%m%dT%H%M%SZ")
  end

  defp aws_encode(value) do
    URI.encode(to_string(value), &URI.char_unreserved?/1)
  end

  defp maybe_put_token(headers, nil), do: headers
  defp maybe_put_token(headers, ""), do: headers
  defp maybe_put_token(headers, token), do: headers ++ [{"x-amz-security-token", token}]

  # ---- Params helpers ----

  defp normalize_params(params) when is_map(params), do: params

  defp normalize_params(params) when is_list(params) do
    Enum.into(params, %{})
  end

  defp normalize_params(_), do: %{}

  defp take_keys(params, keys) when is_map(params), do: params |> Map.take(keys) |> Map.to_list()
  defp take_keys(params, keys) when is_list(params), do: Keyword.take(params, keys)
  defp take_keys(_params, _keys), do: []

  defp valid_voice?(voice_id), do: Enum.any?(@voices, fn v -> v.id == voice_id end)
  defp valid_model?(model_id), do: Enum.any?(@models, fn m -> m.id == model_id end)
end
