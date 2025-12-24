defmodule HipcallTts.Retry do
  @moduledoc """
  Retry helper with exponential backoff and optional retryable error filtering.
  """

  alias HipcallTts.Telemetry

  @type opts :: [
          max_attempts: pos_integer(),
          initial_delay: non_neg_integer(),
          max_delay: non_neg_integer(),
          backoff_factor: float(),
          retryable_errors: [atom()]
        ]

  @spec with_retry((-> {:ok, any()} | {:error, any()}), opts(), keyword()) ::
          {:ok, any()} | {:error, any()}
  def with_retry(fun, opts \\ [], telemetry_meta \\ []) when is_function(fun, 0) do
    max_attempts = Keyword.get(opts, :max_attempts, 3)
    initial_delay = Keyword.get(opts, :initial_delay, 1000)
    max_delay = Keyword.get(opts, :max_delay, 10_000)
    backoff_factor = Keyword.get(opts, :backoff_factor, 2.0)
    retryable_errors = Keyword.get(opts, :retryable_errors, [])

    do_retry(fun,
      attempt: 1,
      max_attempts: max_attempts,
      initial_delay: initial_delay,
      max_delay: max_delay,
      backoff_factor: backoff_factor,
      retryable_errors: retryable_errors,
      telemetry_meta: telemetry_meta
    )
  end

  defp do_retry(fun, state) do
    attempt = state[:attempt]
    max_attempts = state[:max_attempts]

    case fun.() do
      {:ok, result} ->
        {:ok, result}

      {:error, error} ->
        if attempt <= max_attempts and retryable?(error, state[:retryable_errors]) do
          delay_ms = delay_ms(error, state)

          Telemetry.retry_attempt(
            attempt,
            Keyword.merge(
              [delay: delay_ms, max_attempts: max_attempts, error: safe_error(error)],
              state[:telemetry_meta]
            )
          )

          Process.sleep(delay_ms)

          do_retry(fun, Keyword.put(state, :attempt, attempt + 1))
        else
          {:error, error}
        end

      other ->
        {:error, %{code: :invalid_return, message: "retry fun returned: #{inspect(other)}"}}
    end
  end

  # If retryable_errors is empty, we retry all errors (as documented in Schema).
  defp retryable?(_error, []), do: true

  defp retryable?(%{code: code}, retryable_errors) when is_atom(code),
    do: code in retryable_errors

  defp retryable?(_error, _retryable_errors), do: false

  # Prefer Retry-After (seconds) for 429/503
  defp delay_ms(error, state) do
    from_header = retry_after_ms(error)

    if is_integer(from_header) do
      min(from_header, state[:max_delay])
    else
      exp =
        (state[:initial_delay] *
           :math.pow(state[:backoff_factor], max(state[:attempt] - 1, 0)))
        |> round()

      min(exp, state[:max_delay])
    end
  end

  defp retry_after_ms(%{headers: headers}) when is_list(headers) do
    headers
    |> Enum.find_value(fn
      {k, v} when is_binary(k) and is_binary(v) ->
        if String.downcase(k) == "retry-after", do: parse_retry_after(v), else: nil

      _ ->
        nil
    end)
  end

  defp retry_after_ms(_), do: nil

  defp parse_retry_after(value) do
    value = String.trim(value)

    case Integer.parse(value) do
      {seconds, ""} when seconds >= 0 -> seconds * 1000
      _ -> nil
    end
  end

  defp safe_error(error) do
    cond do
      is_binary(error) -> error
      is_map(error) -> Map.take(error, [:code, :message, :status])
      true -> inspect(error)
    end
  end
end
