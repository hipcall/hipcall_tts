defmodule HipcallTts do
  @moduledoc """
  Main public API for `hipcall_tts`.

  Provides:
  - `generate/1` for request/response TTS generation
  - `stream/1` for streaming (delegates to provider)
  - Introspection helpers (`providers/0`, `models/1`, `voices/1`, `languages/1`, `capabilities/1`)
  """

  alias HipcallTts.{AudioConcatenator, Registry, Retry, Schema, Telemetry, TextSplitter}

  @type params :: keyword() | map()

  @doc """
  Generate speech audio from text.

  Parameters are validated via `HipcallTts.Schema.generate_schema/0`.

  Returns `{:ok, audio_binary}` or `{:error, error}`.
  """
  @spec generate(params()) :: {:ok, binary()} | {:error, any()}
  def generate(params) do
    start_time = System.monotonic_time()

    with {:ok, validated} <- validate_params(params),
         provider <- Keyword.fetch!(validated, :provider),
         {:ok, provider_module} <- Registry.get_provider(provider),
         {:ok, chunks} <- maybe_split_text(validated, provider_module, provider),
         {:ok, audio_segments} <- generate_segments(chunks, validated, provider_module, provider),
         {:ok, audio} <- maybe_concatenate(audio_segments) do
      duration = System.monotonic_time() - start_time

      Telemetry.generate_stop(duration,
        provider: provider,
        text_length: String.length(validated[:text]),
        success: true,
        audio_size: byte_size(audio),
        format: validated[:format]
      )

      {:ok, audio}
    else
      {:error, error} ->
        duration = System.monotonic_time() - start_time
        provider = safe_provider(params)

        norm_error = normalize_error(error, provider)

        Telemetry.generate_error(duration, norm_error,
          provider: provider,
          text_length: safe_text_length(params)
        )

        Telemetry.generate_stop(duration,
          provider: provider,
          text_length: safe_text_length(params),
          success: false
        )

        {:error, norm_error}
    end
  rescue
    error ->
      Telemetry.generate_exception(:error, error, __STACKTRACE__,
        provider: safe_provider(params),
        text_length: safe_text_length(params)
      )

      reraise error, __STACKTRACE__
  end

  @doc """
  Stream speech audio.

  Currently delegates directly to the provider's `stream/1`.
  """
  @spec stream(params()) :: {:ok, Enumerable.t()} | {:error, any()}
  def stream(params) do
    with {:ok, validated} <- validate_params(params),
         provider <- Keyword.fetch!(validated, :provider),
         {:ok, provider_module} <- Registry.get_provider(provider) do
      case provider_module.stream(provider_params(validated)) do
        {:ok, result} -> {:ok, result}
        {:error, error} -> {:error, normalize_error(error, provider)}
      end
    else
      {:error, error} ->
        provider = safe_provider(params)
        {:error, normalize_error(error, provider)}
    end
  end

  @doc "List available provider names."
  @spec providers() :: [atom()]
  defdelegate providers(), to: Registry

  @doc "List models for a provider."
  @spec models(atom()) :: {:ok, list()} | {:error, String.t()}
  defdelegate models(provider), to: Registry

  @doc "List voices for a provider."
  @spec voices(atom()) :: {:ok, list()} | {:error, String.t()}
  defdelegate voices(provider), to: Registry

  @doc "List languages for a provider."
  @spec languages(atom()) :: {:ok, list()} | {:error, String.t()}
  defdelegate languages(provider), to: Registry

  @doc "Get capabilities for a provider."
  @spec capabilities(atom()) :: {:ok, map()} | {:error, String.t()}
  defdelegate capabilities(provider), to: Registry

  @doc false
  @spec validate_params(params()) :: {:ok, keyword()} | {:error, any()}
  def validate_params(params) when is_map(params), do: validate_params(Map.to_list(params))

  def validate_params(params) when is_list(params) do
    Telemetry.generate_start(
      provider: Keyword.get(params, :provider),
      text_length: safe_text_length(params)
    )

    NimbleOptions.validate(params, Schema.generate_schema())
  end

  def validate_params(_), do: {:error, "params must be a keyword list or map"}

  defp maybe_split_text(validated, provider_module, provider) do
    caps = provider_module.capabilities()
    max = Map.get(caps, :max_text_length, :infinity)
    text = Keyword.fetch!(validated, :text)

    cond do
      max == :infinity ->
        {:ok, [text]}

      is_integer(max) and String.length(text) > max ->
        TextSplitter.split(text, max, provider: provider)

      true ->
        {:ok, [text]}
    end
  end

  defp generate_segments(chunks, validated, provider_module, provider) do
    retry_opts = Keyword.get(validated, :retry_opts, [])

    chunks
    |> Enum.reduce_while({:ok, []}, fn chunk, {:ok, acc} ->
      call = fn ->
        provider_module.generate(Keyword.put(provider_params(validated), :text, chunk))
      end

      case Retry.with_retry(call, retry_opts, provider: provider) do
        {:ok, audio_bin} when is_binary(audio_bin) ->
          {:cont, {:ok, [audio_bin | acc]}}

        {:ok, other} ->
          {:halt,
           {:error,
            %{code: :invalid_provider_result, message: "expected binary, got: #{inspect(other)}"}}}

        {:error, error} ->
          {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, segments} -> {:ok, Enum.reverse(segments)}
      {:error, error} -> {:error, error}
    end
  end

  defp maybe_concatenate([single]) when is_binary(single), do: {:ok, single}
  defp maybe_concatenate(segments), do: AudioConcatenator.concatenate(segments)

  defp provider_params(validated) do
    provider_opts = Keyword.get(validated, :provider_opts, [])

    validated
    |> Keyword.drop([:provider, :provider_opts])
    |> Keyword.merge(provider_opts)
  end

  defp safe_provider(params) when is_list(params), do: Keyword.get(params, :provider)
  defp safe_provider(params) when is_map(params), do: Map.get(params, :provider)
  defp safe_provider(_), do: nil

  defp safe_text_length(params) when is_list(params) do
    params
    |> Keyword.get(:text, "")
    |> to_string()
    |> String.length()
  end

  defp safe_text_length(params) when is_map(params) do
    params
    |> Map.get(:text, "")
    |> to_string()
    |> String.length()
  end

  defp safe_text_length(_), do: 0

  defp normalize_error(%NimbleOptions.ValidationError{} = err, provider) do
    %{code: :validation_error, message: err.message, provider: provider, error: err}
  end

  defp normalize_error(error, provider) when is_binary(error) do
    %{code: :error, message: error, provider: provider}
  end

  defp normalize_error(error, provider) when is_map(error) do
    error
    |> Map.put_new(:provider, provider)
    |> Map.put_new(:code, :error)
    |> Map.put_new(
      :message,
      Map.get(error, :message) || Map.get(error, "message") || inspect(error)
    )
  end

  defp normalize_error(error, provider) do
    %{code: :error, message: inspect(error), provider: provider}
  end
end
